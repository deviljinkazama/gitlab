module MergeRequests
  # MergeService class
  #
  # Do git fast-forward merge and in case of success
  # mark merge request as merged and execute all hooks and notifications
  # Executed when you do fast-forward merge via GitLab UI
  #
  class FfMergeService < MergeRequests::MergeService
    private

    def commit
      repository.ff_merge(current_user,
                          source,
                          merge_request.target_branch,
                          merge_request: merge_request)
    ensure
      merge_request.update(in_progress_merge_commit_sha: nil)
    end
  end
end