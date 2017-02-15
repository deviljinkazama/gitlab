class MergeRequestEntity < IssuableEntity
  include RequestAwareEntity
  include GitlabMarkdownHelper

  expose :in_progress_merge_commit_sha
  expose :locked_at
  expose :merge_commit_sha
  expose :merge_error
  expose :merge_params
  expose :merge_status
  expose :merge_user_id
  expose :merge_when_pipeline_succeeds
  expose :rebase_commit_sha
  expose :rebase_in_progress?, if: { type: :full }
  expose :source_branch
  expose :source_project_id
  expose :target_branch
  expose :target_project_id

  # EE specific
  expose :approvals_before_merge

  # Events
  expose :merge_event, using: EventEntity
  expose :closed_event, using: EventEntity

  # User entities
  expose :author, using: UserEntity
  expose :merge_user, using: UserEntity

  # Diff sha's
  expose :diff_head_sha
  expose :diff_head_commit_short_id do |merge_request|
    merge_request.diff_head_commit.try(:short_id)
  end

  expose :merge_commit_sha
  expose :merge_commit_message
  expose :head_pipeline, with: PipelineEntity, as: :pipeline

  # Booleans
  expose :work_in_progress?, as: :work_in_progress
  expose :source_branch_exists?, as: :source_branch_exists
  expose :mergeable_discussions_state?, as: :mergeable_discussions_state
  expose :conflicts_can_be_resolved_in_ui?, as: :conflicts_can_be_resolved_in_ui
  expose :branch_missing?, as: :branch_missing
  expose :has_no_commits?, as: :has_no_commits
  expose :can_be_cherry_picked?, as: :can_be_cherry_picked
  expose :cannot_be_merged?, as: :has_conflicts
  expose :can_be_merged?, as: :can_be_merged

  # CI related
  expose :has_ci?, as: :has_ci
  expose :ci_status do |merge_request|
    pipeline = merge_request.head_pipeline

    if pipeline
      status = pipeline.status
      status = "success_with_warnings" if pipeline.success? && pipeline.has_warnings?

      status || "preparing"
    else
      ci_service = merge_request.source_project.try(:ci_service)
      ci_service.commit_status(merge_request.diff_head_sha, merge_request.source_branch) if ci_service
    end
  end

  expose :issues_links do
    expose :closing do |merge_request|
      closes_issues = merge_request.closes_issues(current_user)

      markdown issues_sentence(merge_request.project, closes_issues),
        pipeline: :gfm,
        author: merge_request.author,
        project: merge_request.project
    end

    expose :mentioned_but_not_closing do |merge_request|
      mentioned_but_not_closing_issues = merge_request
        .issues_mentioned_but_not_closing(current_user)

      markdown issues_sentence(merge_request.project, mentioned_but_not_closing_issues),
               pipeline: :gfm,
               author: merge_request.author,
               project: merge_request.project
    end
  end

  expose :current_user do
    expose :can_create_issue do |merge_request|
      merge_request.project.issues_enabled? &&
        can?(request.current_user, :create_issue, merge_request.project)
    end

    expose :can_update_merge_request do |merge_request|
      merge_request.project.merge_requests_enabled? &&
        can?(request.current_user, :update_merge_request, merge_request.project)
    end

    expose :can_resolve_conflicts do |merge_request|
      merge_request.conflicts_can_be_resolved_by?(request.current_user)
    end

    expose :can_remove_source_branch do |merge_request|
      merge_request.can_remove_source_branch?(request.current_user)
    end

    expose :can_merge do |merge_request|
      merge_request.can_be_merged_by?(request.current_user)
    end

    expose :can_merge_via_cli do |merge_request|
      merge_request.can_be_merged_via_command_line_by?(request.current_user)
    end

    expose :can_revert do |merge_request|
      merge_request.can_be_reverted?(request.current_user)
    end

    expose :can_cancel_automatic_merge do |merge_request|
      merge_request.can_cancel_merge_when_pipeline_succeeds?(request.current_user)
    end
  end

  expose :target_branch_path do |merge_request|
    namespace_project_branch_path(merge_request.target_project.namespace,
                                  merge_request.target_project,
                                  merge_request.target_branch)
  end

  expose :source_branch_path do |merge_request|
    namespace_project_branch_path(merge_request.source_project.namespace,
                                  merge_request.source_project,
                                  merge_request.source_branch)
  end

  expose :project_archived do |merge_request|
    merge_request.project.archived?
  end

  expose :conflict_resolution_ui_path do |merge_request|
    conflicts_namespace_project_merge_request_path(merge_request.project.namespace,
                                                   merge_request.project,
                                                   merge_request)
  end

  expose :remove_wip_path do |merge_request|
    remove_wip_namespace_project_merge_request_path(merge_request.project.namespace,
                                                    merge_request.project,
                                                    merge_request)
  end

  expose :merge_path do |merge_request|
    merge_namespace_project_merge_request_path(merge_request.project.namespace,
                                               merge_request.project,
                                               merge_request)
  end

  expose :cancel_merge_when_pipeline_succeeds_path do |merge_request|
    cancel_merge_when_pipeline_succeeds_namespace_project_merge_request_path(
      merge_request.target_project.namespace,
      merge_request.target_project,
      merge_request)
  end

  expose :merge_commit_message_with_description do |merge_request|
    merge_request.merge_commit_message(include_description: true)
  end

  expose :diverged_commits_count do |merge_request|
    merge_request.open? &&
      merge_request.diverged_from_target_branch? ?
        merge_request.diverged_commits_count : 0
  end

  expose :email_patches_path do |merge_request|
    namespace_project_merge_request_path(merge_request.target_project.namespace,
                                         merge_request.target_project,
                                         merge_request,
                                         format: :patch)
  end

  expose :plain_diff_path do |merge_request|
    namespace_project_merge_request_path(merge_request.target_project.namespace,
                                         merge_request.target_project,
                                         merge_request,
                                         format: :diff)
  end

  expose :ci_status_path do |merge_request|
    ci_status_namespace_project_merge_request_path(merge_request.target_project.namespace,
                                         merge_request.target_project,
                                         merge_request)
  end

  # FIXME: @oswaldo, please implement this
  expose :status_path do |merge_request|
    path = namespace_project_merge_request_path(merge_request.target_project.namespace,
                                         merge_request.target_project,
                                         merge_request,
                                         format: :diff)
    path.sub! 'diff', 'json'
  end

  # TODO: @oswaldo, please verify this
  expose :merge_check_path do |merge_request|
    merge_check_namespace_project_merge_request_path(merge_request.target_project.namespace,
                                         merge_request.target_project,
                                         merge_request)
  end

  expose :only_allow_merge_if_pipeline_succeeds do |merge_request|
    merge_request.project.only_allow_merge_if_pipeline_succeeds?
  end

  expose :create_issue_to_resolve_discussions_path do |merge_request|
    new_namespace_project_issue_path(merge_request.project.namespace,
                                     merge_request.project,
                                     merge_request_for_resolving_discussions_of: merge_request.iid)
  end

  expose :ci_environments_status_url do |merge_request|
    ci_environments_status_namespace_project_merge_request_path(merge_request.project.namespace,
                                                                merge_request.project,
                                                                merge_request)
  end

  private

  delegate :current_user, to: :request

  def issues_sentence(project, issues)
    # Sorting based on the `#123` or `group/project#123` reference will sort
    # local issues first.
    issues.map do |issue|
      issue.to_reference(project)
    end.sort.to_sentence
  end
end
