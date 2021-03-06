class GitPushService < BaseService
  attr_accessor :push_data, :push_commits
  include Gitlab::CurrentSettings
  include Gitlab::Access

  # The N most recent commits to process in a single push payload.
  PROCESS_COMMIT_LIMIT = 100

  # This method will be called after each git update
  # and only if the provided user and project are present in GitLab.
  #
  # All callbacks for post receive action should be placed here.
  #
  # Next, this method:
  #  1. Creates the push event
  #  2. Updates merge requests
  #  3. Recognizes cross-references from commit messages
  #  4. Executes the project's webhooks
  #  5. Executes the project's services
  #  6. Checks if the project's main language has changed
  #
  def execute
    @project.repository.after_create if @project.empty_repo?
    @project.repository.after_push_commit(branch_name)

    if push_remove_branch?
      @project.repository.after_remove_branch
      @push_commits = []
    elsif push_to_new_branch?
      @project.repository.after_create_branch

      # Re-find the pushed commits.
      if is_default_branch?
        # Initial push to the default branch. Take the full history of that branch as "newly pushed".
        process_default_branch
      else
        # Use the pushed commits that aren't reachable by the default branch
        # as a heuristic. This may include more commits than are actually pushed, but
        # that shouldn't matter because we check for existing cross-references later.
        @push_commits = @project.repository.commits_between(@project.default_branch, params[:newrev])

        # don't process commits for the initial push to the default branch
        process_commit_messages
      end
    elsif push_to_existing_branch?
      # Collect data for this git push
      @push_commits = @project.repository.commits_between(params[:oldrev], params[:newrev])
      process_commit_messages

      # Update the bare repositories info/attributes file using the contents of the default branches
      # .gitattributes file
      update_gitattributes if is_default_branch?
    end

    if current_application_settings.elasticsearch_indexing? && is_default_branch?
      ElasticCommitIndexerWorker.perform_async(@project.id, params[:oldrev], params[:newrev])
    end

    execute_related_hooks
    perform_housekeeping

    update_remote_mirrors
    update_caches
  end

  def update_gitattributes
    @project.repository.copy_gitattributes(params[:ref])
  end

  def update_caches
    if is_default_branch?
      paths = Set.new

      @push_commits.each do |commit|
        commit.raw_deltas.each do |diff|
          paths << diff.new_path
        end
      end

      types = Gitlab::FileDetector.types_in_paths(paths.to_a)
    else
      types = []
    end

    ProjectCacheWorker.perform_async(@project.id, types, [:commit_count, :repository_size])
  end

  # Schedules processing of commit messages.
  def process_commit_messages
    default = is_default_branch?

    push_commits.last(PROCESS_COMMIT_LIMIT).each do |commit|
      if commit.matches_cross_reference_regex?
        ProcessCommitWorker.
          perform_async(project.id, current_user.id, commit.to_hash, default)
      end
    end
  end

  protected

  def update_remote_mirrors
    return if @project.remote_mirrors.empty?

    @project.mark_stuck_remote_mirrors_as_failed!
    @project.update_remote_mirrors
  end

  def execute_related_hooks
    # Update merge requests that may be affected by this push. A new branch
    # could cause the last commit of a merge request to change.
    #
    UpdateMergeRequestsWorker
      .perform_async(@project.id, current_user.id, params[:oldrev], params[:newrev], params[:ref])

    mirror_update = @project.mirror? && @project.repository.up_to_date_with_upstream?(branch_name)

    EventCreateService.new.push(@project, current_user, build_push_data)
    Ci::CreatePipelineService.new(@project, current_user, build_push_data).execute(:push, mirror_update: mirror_update)
    
    SystemHookPushWorker.perform_async(build_push_data.dup, :push_hooks)
    @project.execute_hooks(build_push_data.dup, :push_hooks)
    @project.execute_services(build_push_data.dup, :push_hooks)

    if push_remove_branch?
      AfterBranchDeleteService
        .new(project, current_user)
        .execute(branch_name)
    end
  end

  def perform_housekeeping
    housekeeping = Projects::HousekeepingService.new(@project)
    housekeeping.increment!
    housekeeping.execute if housekeeping.needed?
  rescue Projects::HousekeepingService::LeaseTaken
  end

  def process_default_branch
    @push_commits = project.repository.commits(params[:newrev])

    # Ensure HEAD points to the default branch in case it is not master
    project.change_head(branch_name)

    # Set protection on the default branch if configured
    if current_application_settings.default_branch_protection != PROTECTION_NONE && !ProtectedBranch.protected?(@project, @project.default_branch)

      params = {
        name: @project.default_branch,
        push_access_levels_attributes: [{
          access_level: current_application_settings.default_branch_protection == PROTECTION_DEV_CAN_PUSH ? Gitlab::Access::DEVELOPER : Gitlab::Access::MASTER
        }],
        merge_access_levels_attributes: [{
          access_level: current_application_settings.default_branch_protection == PROTECTION_DEV_CAN_MERGE ? Gitlab::Access::DEVELOPER : Gitlab::Access::MASTER
        }]
      }

      ProtectedBranches::CreateService.new(@project, current_user, params).execute
    end
  end

  def build_push_data
    @push_data ||= Gitlab::DataBuilder::Push.build(
      @project,
      current_user,
      params[:oldrev],
      params[:newrev],
      params[:ref],
      push_commits)
  end

  def push_to_existing_branch?
    # Return if this is not a push to a branch (e.g. new commits)
    Gitlab::Git.branch_ref?(params[:ref]) && !Gitlab::Git.blank_ref?(params[:oldrev])
  end

  def push_to_new_branch?
    Gitlab::Git.branch_ref?(params[:ref]) && Gitlab::Git.blank_ref?(params[:oldrev])
  end

  def push_remove_branch?
    Gitlab::Git.branch_ref?(params[:ref]) && Gitlab::Git.blank_ref?(params[:newrev])
  end

  def push_to_branch?
    Gitlab::Git.branch_ref?(params[:ref])
  end

  def is_default_branch?
    Gitlab::Git.branch_ref?(params[:ref]) &&
      (Gitlab::Git.ref_name(params[:ref]) == project.default_branch || project.default_branch.nil?)
  end

  def commit_user(commit)
    commit.author || current_user
  end

  def branch_name
    @branch_name ||= Gitlab::Git.ref_name(params[:ref])
  end
end
