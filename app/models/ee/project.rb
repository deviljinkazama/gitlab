module EE
  # Project EE mixin
  #
  # This module is intended to encapsulate EE-specific model logic
  # and be prepended in the `Project` model
  module Project
    extend ActiveSupport::Concern

    prepended do
      include IgnorableColumn

      ignore_column :sync_time

      before_validation :mark_remote_mirrors_for_removal

      after_save :create_mirror_data, if: ->(project) { project.mirror? && project.mirror_changed? }
      after_save :destroy_mirror_data, if: ->(project) { !project.mirror? && project.mirror_changed? }

      after_update :remove_mirror_repository_reference,
        if: ->(project) { project.mirror? && project.import_url_updated? }

      belongs_to :mirror_user, foreign_key: 'mirror_user_id', class_name: 'User'

      has_one :mirror_data, dependent: :delete, autosave: true, class_name: 'ProjectMirrorData'
      has_one :push_rule, dependent: :destroy
      has_one :index_status, dependent: :destroy
      has_one :jenkins_service, dependent: :destroy
      has_one :jenkins_deprecated_service, dependent: :destroy

      has_many :approvers, as: :target, dependent: :destroy
      has_many :approver_groups, as: :target, dependent: :destroy
      has_many :audit_events, as: :entity, dependent: :destroy
      has_many :remote_mirrors, inverse_of: :project, dependent: :destroy
      has_many :path_locks, dependent: :destroy

      scope :with_shared_runners_limit_enabled, -> { with_shared_runners.non_public_only }

      scope :mirrors_to_sync, -> do
        mirror.joins(:mirror_data).where("next_execution_timestamp <= ? AND import_status NOT IN ('scheduled', 'started')", Time.now).
          order_by(:next_execution_timestamp).limit(::Gitlab::Mirror.available_capacity)
      end

      scope :stuck_mirrors, -> do
        mirror.joins(:mirror_data).
          where("(import_status = 'started' AND project_mirror_data.last_update_started_at < :limit) OR (import_status = 'scheduled' AND project_mirror_data.last_update_scheduled_at < :limit)",
                { limit: 20.minutes.ago })
      end

      scope :mirror, -> { where(mirror: true) }
      scope :with_remote_mirrors, -> { joins(:remote_mirrors).where(remote_mirrors: { enabled: true }).distinct }
      scope :with_wiki_enabled, -> { with_feature_enabled(:wiki) }

      delegate :shared_runners_minutes, :shared_runners_seconds, :shared_runners_seconds_last_reset,
        to: :statistics, allow_nil: true

      delegate :actual_shared_runners_minutes_limit,
        :shared_runners_minutes_used?, to: :namespace

      validates :repository_size_limit,
        numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }

      validates :approvals_before_merge, numericality: true, allow_blank: true

      accepts_nested_attributes_for :remote_mirrors,
        allow_destroy: true,
        reject_if: ->(attrs) { attrs[:id].blank? && attrs[:url].blank? }

      with_options if: :mirror? do |project|
        project.validates :import_url, presence: true
        project.validates :mirror_user, presence: true
      end
    end

    module ClassMethods
      def search_by_visibility(level)
        where(visibility_level: ::Gitlab::VisibilityLevel.string_options[level])
      end
    end

    def mirror_updated?
      mirror? && self.mirror_last_update_at
    end

    def updating_mirror?
      return false unless mirror? && !empty_repo?
      return true if import_in_progress?

      self.mirror_data.next_execution_timestamp < Time.now
    end

    def mirror_last_update_status
      return unless mirror_updated?

      if self.mirror_last_update_at == self.mirror_last_successful_update_at
        :success
      else
        :failed
      end
    end

    def mirror_last_update_success?
      mirror_last_update_status == :success
    end

    def mirror_last_update_failed?
      mirror_last_update_status == :failed
    end

    def mirror_ever_updated_successfully?
      mirror_updated? && self.mirror_last_successful_update_at
    end

    def has_remote_mirror?
      remote_mirrors.enabled.exists?
    end

    def updating_remote_mirror?
      remote_mirrors.enabled.started.exists?
    end

    def update_remote_mirrors
      remote_mirrors.each(&:sync)
    end

    def mark_stuck_remote_mirrors_as_failed!
      remote_mirrors.stuck.update_all(
        update_status: :failed,
        last_error: 'The remote mirror took to long to complete.',
        last_update_at: Time.now
      )
    end

    def fetch_mirror
      return unless mirror?

      repository.fetch_upstream(self.import_url)
    end

    def shared_runners_available?
      super && !namespace.shared_runners_minutes_used?
    end

    def shared_runners_minutes_limit_enabled?
      !public? && shared_runners_enabled? && namespace.shared_runners_minutes_limit_enabled?
    end

    # Checks licensed feature availability if `feature` matches any
    # key on License::FEATURE_CODES. Otherwise, check feature availability
    # through ProjectFeature.
    def feature_available?(feature, user = nil)
      if License::FEATURE_CODES.key?(feature)
        licensed_feature_available?(feature)
      else
        super
      end
    end

    def service_desk_enabled
      ::EE::Gitlab::ServiceDesk.enabled?(project: self) && super
    end
    alias_method :service_desk_enabled?, :service_desk_enabled

    def service_desk_address
      return nil unless service_desk_enabled?

      config = ::Gitlab.config.incoming_email
      wildcard = ::Gitlab::IncomingEmail::WILDCARD_PLACEHOLDER

      config.address&.gsub(wildcard, full_path)
    end

    def force_import_job!
      self.mirror_data.set_next_execution_to_now!
      UpdateAllMirrorsWorker.perform_async
    end

    def add_import_job
      if import? && !repository_exists?
        super
      elsif mirror?
        ::Gitlab::Mirror.increment_metric(:mirrors_scheduled, 'Mirrors scheduled count')

        RepositoryUpdateMirrorWorker.perform_async(self.id)
      end
    end

    def cache_has_external_issue_tracker
      super unless ::Gitlab::Geo.secondary?
    end

    def cache_has_external_wiki
      super unless ::Gitlab::Geo.secondary?
    end

    def execute_hooks(data, hooks_scope = :push_hooks)
      super

      if group
        group.hooks.send(hooks_scope).each do |hook|
          hook.async_execute(data, hooks_scope.to_s)
        end
      end
    end

    # No need to have a Kerberos Web url. Kerberos URL will be used only to
    # clone
    def kerberos_url_to_repo
      "#{::Gitlab.config.build_gitlab_kerberos_url + ::Gitlab::Application.routes.url_helpers.namespace_project_path(self.namespace, self)}.git"
    end

    def group_ldap_synced?
      if group
        group.ldap_synced?
      else
        false
      end
    end

    def reference_issue_tracker?
      default_issues_tracker? || jira_tracker_active?
    end

    def approver_ids=(value)
      value.split(",").map(&:strip).each do |user_id|
        approvers.find_or_create_by(user_id: user_id, target_id: id)
      end
    end

    def approver_group_ids=(value)
      value.split(",").map(&:strip).each do |group_id|
        approver_groups.find_or_initialize_by(group_id: group_id, target_id: id)
      end
    end

    def find_path_lock(path, exact_match: false, downstream: false)
      @path_lock_finder ||= ::Gitlab::PathLocksFinder.new(self)
      @path_lock_finder.find(path, exact_match: exact_match, downstream: downstream)
    end

    def merge_method
      if self.merge_requests_ff_only_enabled
        :ff
      elsif self.merge_requests_rebase_enabled
        :rebase_merge
      else
        :merge
      end
    end

    def merge_method=(method)
      case method.to_s
      when "ff"
        self.merge_requests_ff_only_enabled = true
        self.merge_requests_rebase_enabled = true
      when "rebase_merge"
        self.merge_requests_ff_only_enabled = false
        self.merge_requests_rebase_enabled = true
      when "merge"
        self.merge_requests_ff_only_enabled = false
        self.merge_requests_rebase_enabled = false
      end
    end

    def ff_merge_must_be_possible?
      self.merge_requests_ff_only_enabled || self.merge_requests_rebase_enabled
    end

    def import_url_updated?
      # check if import_url has been updated and it's not just the first assignment
      import_url_changed? && changes['import_url'].first
    end

    def remove_mirror_repository_reference
      repository.remove_remote(Repository::MIRROR_REMOTE)
    end

    def import_url_availability
      if remote_mirrors.find_by(url: import_url)
        errors.add(:import_url, 'is already in use by a remote mirror')
      end
    end

    def mark_remote_mirrors_for_removal
      remote_mirrors.each(&:mark_for_delete_if_blank_url)
    end

    def change_repository_storage(new_repository_storage_key)
      return if repository_read_only?
      return if repository_storage == new_repository_storage_key

      raise ArgumentError unless ::Gitlab.config.repositories.storages.keys.include?(new_repository_storage_key)

      run_after_commit { ProjectUpdateRepositoryStorageWorker.perform_async(id, new_repository_storage_key) }
      self.repository_read_only = true
    end

    def repository_and_lfs_size
      statistics.total_repository_size
    end

    def above_size_limit?
      return false unless size_limit_enabled?

      repository_and_lfs_size > actual_size_limit
    end

    def size_to_remove
      repository_and_lfs_size - actual_size_limit
    end

    def actual_size_limit
      return namespace.actual_size_limit if repository_size_limit.nil?

      repository_size_limit
    end

    def size_limit_enabled?
      actual_size_limit != 0
    end

    def changes_will_exceed_size_limit?(size_in_bytes)
      size_limit_enabled? &&
        (size_in_bytes > actual_size_limit ||
         size_in_bytes + repository_and_lfs_size > actual_size_limit)
    end

    def remove_import_data
      super unless mirror?
    end

    private

    def licensed_feature_available?(feature)
      globally_available = License.feature_available?(feature)

      if current_application_settings.should_check_namespace_plan?
        globally_available &&
          (public? && namespace.public? || namespace.feature_available?(feature))
      else
        globally_available
      end
    end

    def destroy_mirror_data
      mirror_data.destroy
    end
  end
end
