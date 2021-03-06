module Groups
  class UpdateService < Groups::BaseService
    def execute
      reject_parent_id!

      # check that user is allowed to set specified visibility_level
      new_visibility = params[:visibility_level]
      if new_visibility && new_visibility.to_i != group.visibility_level
        unless can?(current_user, :change_visibility_level, group) &&
            Gitlab::VisibilityLevel.allowed_for?(current_user, new_visibility)

          deny_visibility_level(group, new_visibility)
          return group
        end
      end

      # Repository size limit comes as MB from the view
      limit = @params.delete(:repository_size_limit)
      group.repository_size_limit = Gitlab::Utils.try_megabytes_to_bytes(limit) if limit

      group.assign_attributes(params)

      begin
        group.save
      rescue Gitlab::UpdatePathError => e
        group.errors.add(:base, e.message)

        false
      end
    end

    private

    def reject_parent_id!
      params.except!(:parent_id)
    end
  end
end
