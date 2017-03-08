module Projects
  module Settings
    class RepositoryController < Projects::ApplicationController
      before_action :authorize_admin_project!
      before_action :push_rule, only: [:show]
      before_action :remote_mirror, only: [:show]

      def show
        @deploy_keys = DeployKeysPresenter
          .new(@project, current_user: current_user)

        define_protected_branches
      end      

      private

      def define_protected_branches
        load_protected_branches
        @protected_branch = @project.protected_branches.new
        load_gon_index
      end

      def push_rule
        @push_rule ||= PushRule.find_or_create_by(is_sample: true)
      end

      def remote_mirror
        @remote_mirror = @project.remote_mirrors.first_or_initialize
      end

      def load_protected_branches
        @protected_branches = @project.protected_branches.order(:name).page(params[:page])
      end

      def access_levels_options
        {
          push_access_levels: {
            roles: ProtectedBranch::PushAccessLevel.human_access_levels.map { |id, text| { id: id, text: text, before_divider: true } },
          },
          merge_access_levels: {
            roles: ProtectedBranch::MergeAccessLevel.human_access_levels.map { |id, text| { id: id, text: text, before_divider: true } },
          },
          selected_merge_access_levels: @protected_branch.merge_access_levels.map { |access_level| access_level.user_id || access_level.access_level },
          selected_push_access_levels: @protected_branch.push_access_levels.map { |access_level| access_level.user_id || access_level.access_level }
        }
      end
      
      def open_branches
        branches = @project.open_branches.map { |br| { text: br.name, id: br.name, title: br.name } }
        { open_branches: branches }
      end

      def load_gon_index
        params = open_branches
        params[:current_project_id] = @project.id if @project
        gon.push(params.merge(access_levels_options))
      end
    end
  end
end
