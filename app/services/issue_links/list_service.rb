module IssueLinks
  class ListService
    include Gitlab::Routing

    def initialize(issue, user)
      @issue, @current_user, @project = issue, user, issue.project
    end

    def execute
      issues.map do |referenced_issue|
        {
          id: referenced_issue.id,
          iid: referenced_issue.iid,
          title: referenced_issue.title,
          state: referenced_issue.state,
          project_path: referenced_issue.project.path,
          namespace_full_path: referenced_issue.project.namespace.full_path,
          path: namespace_project_issue_path(referenced_issue.project.namespace, referenced_issue.project, referenced_issue.iid),
          destroy_relation_path: destroy_relation_path(referenced_issue)
        }
      end
    end

    private

    def issues
      related_issues = Issue
                         .select(['issues.*', 'issue_links.id AS issue_links_id'])
                         .joins("INNER JOIN issue_links ON
                                 (issue_links.source_id = issues.id AND issue_links.target_id = #{@issue.id})
                                 OR
                                 (issue_links.target_id = issues.id AND issue_links.source_id = #{@issue.id})")
                         .preload(project: :namespace)
                         .reorder('issue_links_id')

      Ability.issues_readable_by_user(related_issues, @current_user)
    end

    def destroy_relation_path(issue)
      # Make sure the user can admin both the current issue AND the
      # referenced issue projects in order to return the removal link.
      if can_destroy_issue_link_on_current_project? && can_destroy_issue_link?(issue.project)
        namespace_project_issue_link_path(@project.namespace,
                                          @issue.project,
                                          @issue.iid,
                                          issue.issue_links_id)
      end
    end

    def can_destroy_issue_link_on_current_project?
      return @can_destroy_on_current_project if defined?(@can_destroy_on_current_project)

      @can_destroy_on_current_project = can_destroy_issue_link?(@project)
    end

    def can_destroy_issue_link?(project)
      Ability.allowed?(@current_user, :admin_issue_link, project)
    end
  end
end
