# LDAP authorization model
#
# * Check if we are allowed access (not blocked)
# * Update authorizations and associations
#
module Gitlab
  module LDAP
    class Access
      attr_reader :adapter, :provider, :user, :ldap_user, :ldap_identity

      def self.open(user, &block)
        Gitlab::LDAP::Adapter.open(user.ldap_identity.provider) do |adapter|
          block.call(self.new(user, adapter))
        end
      end

      def self.allowed?(user, options = {})
        self.open(user) do |access|
          # Whether user is allowed, or not, we should update
          # permissions to keep things clean
          if access.allowed?
            access.update_user
            user.last_credential_check_at = Time.now
            user.save
            true
          else
            false
          end
        end
      end

      def initialize(user, adapter = nil)
        @adapter = adapter
        @user = user
        @provider = adapter&.provider || user.ldap_identity.provider
        @ldap_identity = user.identities.find_by(provider: @provider)
      end

      def allowed?
        if ldap_user
          unless ldap_config.active_directory
            unblock_user(user, 'is available again') if user.ldap_blocked?
            return true
          end

          # Block user in GitLab if he/she was blocked in AD
          if Gitlab::LDAP::Person.disabled_via_active_directory?(ldap_identity.extern_uid, adapter)
            block_user(user, 'is disabled in Active Directory')
            false
          else
            unblock_user(user, 'is not disabled anymore') if user.ldap_blocked?
            true
          end
        else
          # Block the user if they no longer exist in LDAP/AD
          block_user(user, 'does not exist anymore')
          false
        end
      end

      def adapter
        @adapter ||= Gitlab::LDAP::Adapter.new(provider)
      end

      def ldap_config
        Gitlab::LDAP::Config.new(provider)
      end

      def find_ldap_user
        found_user = Gitlab::LDAP::Person.find_by_dn(ldap_identity.extern_uid, adapter)
        return found_user if found_user

        if user.external_email? && [nil, provider].include?(user.email_provider)
          Gitlab::LDAP::Person.find_by_email(user.email, adapter)
        end
      end

      def ldap_user
        @ldap_user ||= find_ldap_user
      end

      def block_user(user, reason)
        user.ldap_block

        Gitlab::AppLogger.info(
          "LDAP account \"#{ldap_identity.extern_uid}\" #{reason}, " \
          "blocking Gitlab user \"#{user.name}\" (#{user.email})"
        )
      end

      def unblock_user(user, reason)
        user.activate

        Gitlab::AppLogger.info(
          "LDAP account \"#{ldap_identity.extern_uid}\" #{reason}, " \
          "unblocking Gitlab user \"#{user.name}\" (#{user.email})"
        )
      end

      def update_user
        update_email
        update_memberships
        update_identity
        update_ssh_keys if sync_ssh_keys?
        update_kerberos_identity if import_kerberos_identities?
      end

      # Update user ssh keys if they changed in LDAP
      def update_ssh_keys
        remove_old_ssh_keys
        add_new_ssh_keys
      end

      # Add ssh keys that are in LDAP but not in GitLab
      def add_new_ssh_keys
        keys = ldap_user.ssh_keys - user.keys.ldap.pluck(:key)

        keys.each do |key|
          logger.info "#{self.class.name}: adding LDAP SSH key #{key.inspect} to #{user.name} (#{user.id})"
          new_key = LDAPKey.new(title: "LDAP - #{ldap_config.sync_ssh_keys}", key: key)
          new_key.user = user

          unless new_key.save
            logger.error "#{self.class.name}: failed to add LDAP SSH key #{key.inspect} to #{user.name} (#{user.id})\n"\
              "error messages: #{new_key.errors.messages}"
          end
        end
      end

      # Remove ssh keys that do not exist in LDAP any more
      def remove_old_ssh_keys
        keys = user.keys.ldap.where.not(key: ldap_user.ssh_keys)

        keys.each do |deleted_key|
          logger.info "#{self.class.name}: removing LDAP SSH key #{deleted_key.key} from #{user.name} (#{user.id})"

          unless deleted_key.destroy
            logger.error "#{self.class.name}: failed to remove LDAP SSH key #{key.inspect} from #{user.name} (#{user.id})"
          end
        end
      end

      # Update user Kerberos identity with Kerberos principal name from Active Directory
      def update_kerberos_identity
        # there can be only one Kerberos identity in GitLab; if the user has a Kerberos identity in AD,
        # replace any existing Kerberos identity for the user
        return unless ldap_user.kerberos_principal.present?
        kerberos_identity = user.identities.where(provider: :kerberos).first
        return if kerberos_identity && kerberos_identity.extern_uid == ldap_user.kerberos_principal
        kerberos_identity ||= Identity.new(provider: :kerberos, user: user)
        kerberos_identity.extern_uid = ldap_user.kerberos_principal
        unless kerberos_identity.save
          Rails.logger.error "#{self.class.name}: failed to add Kerberos principal #{principal} to #{user.name} (#{user.id})\n"\
            "error messages: #{new_identity.errors.messages}"
        end
      end

      # Update user email if it changed in LDAP
      def update_email
        return false unless ldap_user.try(:email)

        ldap_email = ldap_user.email.last.to_s.downcase

        return false if user.email == ldap_email

        user.skip_reconfirmation!
        user.update(email: ldap_email)
      end

      def update_identity
        return if ldap_user.dn.empty? || ldap_user.dn == ldap_identity.extern_uid

        unless ldap_identity.update(extern_uid: ldap_user.dn)
          Rails.logger.error "Could not update DN for #{user.name} (#{user.id})\n"\
                             "error messages: #{user.ldap_identity.errors.messages}"
        end
      end

      delegate :sync_ssh_keys?, to: :ldap_config

      def import_kerberos_identities?
        # Kerberos may be enabled for Git HTTP access and/or as an Omniauth provider
        ldap_config.active_directory && (Gitlab.config.kerberos.enabled || AuthHelper.kerberos_enabled? )
      end

      def update_memberships
        return if ldap_user.nil? || ldap_user.group_cns.empty?

        group_ids = LdapGroupLink.where(cn: ldap_user.group_cns, provider: provider)
                      .distinct(:group_id)
                      .pluck(:group_id)

        LdapGroupSyncWorker.perform_async(group_ids, provider) if group_ids.any?
      end

      private

      def logger
        Rails.logger
      end
    end
  end
end
