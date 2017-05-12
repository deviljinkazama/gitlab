# Finders::MergeRequest class
#
# Used to filter MergeRequests collections by set of params
#
# Arguments:
#   current_user - which user use
#   params:
#     scope: 'created-by-me' or 'assigned-to-me' or 'all'
#     state: 'open', 'closed', 'merged', or 'all'
#     group_id: integer
#     project_id: integer
#     milestone_title: string
#     assignee_id: integer
#     search: string
#     label_name: string
#     sort: string
#     non_archived: boolean
#
class MergeRequestsFinder < IssuableFinder
  def klass
    MergeRequest
  end

  private

  def by_assignee(items)
    if assignee
      items = items.where(assignee_id: assignee.id)
    elsif no_assignee?
      items = items.where(assignee_id: nil)
    elsif assignee_id? || assignee_username? # assignee not found
      items = items.none
    end

    items
  end

  def item_project_ids(items)
    items&.reorder(nil)&.select(:target_project_id)
  end
end
