module EE
  # User EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `User` model
  module User
    extend ActiveSupport::Concern
    include AuditorUserHelper

    included do
      # We aren't using the `auditor?` method for the `if` condition here
      # because `auditor?` returns `false` when the `auditor` column is `true`
      # and the auditor add-on absent. We want to run this validation
      # regardless of the add-on's presence, so we need to check the `auditor`
      # column directly.
      validate :auditor_requires_license_add_on, if: :auditor
      validate :cannot_be_admin_and_auditor

      delegate :shared_runners_minutes_limit, :shared_runners_minutes_limit=,
               to: :namespace
    end

    module ClassMethods
      def support_bot
        email_pattern = "support%s@#{Settings.gitlab.host}"

        unique_internal(where(support_bot: true), 'support-bot', email_pattern) do |u|
          u.bio = 'The GitLab support bot used for Service Desk'
          u.name = 'GitLab Support Bot'
        end
      end

      # override
      def internal_attributes
        super + [:support_bot]
      end
    end

    def cannot_be_admin_and_auditor
      if admin? && auditor?
        errors.add(:admin, "user cannot also be an Auditor.")
      end
    end

    def auditor_requires_license_add_on
      unless license_allows_auditor_user?
        errors.add(:auditor, 'user cannot be created without the "GitLab_Auditor_User" addon')
      end
    end

    def auditor?
      license_allows_auditor_user? && self.auditor
    end

    def admin_or_auditor?
      admin? || auditor?
    end

    def remember_me!
      return if ::Gitlab::Geo.secondary?
      super
    end

    def forget_me!
      return if ::Gitlab::Geo.secondary?
      super
    end
  end
end
