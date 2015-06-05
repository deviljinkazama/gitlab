module Gitlab
  class GitAccess
    DOWNLOAD_COMMANDS = %w{ git-upload-pack git-upload-archive }
    PUSH_COMMANDS = %w{ git-receive-pack }
    GIT_ANNEX_COMMANDS = %w{ git-annex-shell }

    attr_reader :actor, :project

    def initialize(actor, project)
      @actor    = actor
      @project  = project
    end

    def user
      return @user if defined?(@user)

      @user =
        case actor
        when User
          actor
        when DeployKey
          nil
        when Key
          actor.user
        end
    end

    def deploy_key
      actor if actor.is_a?(DeployKey)
    end

    def can_push_to_branch?(ref)
      return false unless user

      if project.protected_branch?(ref) && !project.developers_can_push_to_protected_branch?(ref)
        user.can?(:push_code_to_protected_branches, project)
      else
        user.can?(:push_code, project)
      end
    end

    def can_read_project?
      if user
        user.can?(:read_project, project)
      elsif deploy_key
        deploy_key.projects.include?(project)
      else
        false
      end
    end

    def check(cmd, changes = nil)
      unless actor
        return build_status_object(false, "No user or key was provided.")
      end

      if user && !user_allowed?
        return build_status_object(false, "Your account has been blocked.")
      end

      unless project && can_read_project?
        return build_status_object(false, 'The project you were looking for could not be found.')
      end

      case cmd
      when *DOWNLOAD_COMMANDS
        download_access_check
      when *PUSH_COMMANDS
        push_access_check(changes)
      when *GIT_ANNEX_COMMANDS
        git_annex_access_check(project, changes)
      else
        build_status_object(false, "The command you're trying to execute is not allowed.")
      end
    end

    def download_access_check
      if user
        user_download_access_check
      elsif deploy_key
        build_status_object(true)
      else
        raise 'Wrong actor'
      end
    end

    def push_access_check(changes)
      if user
        user_push_access_check(changes)
      elsif deploy_key
        build_status_object(false, "Deploy keys are not allowed to push code.")
      else
        raise 'Wrong actor'
      end
    end

    def user_download_access_check
      unless user.can?(:download_code, project)
        return build_status_object(false, "You are not allowed to download code from this project.")
      end

      build_status_object(true)
    end

    def user_push_access_check(changes)
      if changes.blank?
        return build_status_object(true)
      end

      unless project.repository.exists?
        return build_status_object(false, "A repository for this project does not exist yet.")
      end

      if ::License.block_changes?
        message = ::LicenseHelper.license_message(signed_in: true, is_admin: (user && user.is_admin?))
        return build_status_object(false, message)
      end

      changes = changes.lines if changes.kind_of?(String)

      # Iterate over all changes to find if user allowed all of them to be applied
      changes.map(&:strip).reject(&:blank?).each do |change|
        status = change_access_check(change)
        unless status.allowed?
          # If user does not have access to make at least one change - cancel all push
          return status
        end
      end

      build_status_object(true)
    end

    def change_access_check(change)
      oldrev, newrev, ref = change.split(' ')

      action =
        if project.protected_branch?(branch_name(ref))
          protected_branch_action(oldrev, newrev, branch_name(ref))
        elsif protected_tag?(tag_name(ref))
          # Prevent any changes to existing git tag unless user has permissions
          :admin_project
        else
          :push_code
        end

      unless user.can?(action, project)
        status =
          case action
          when :force_push_code_to_protected_branches
            build_status_object(false, "You are not allowed to force push code to a protected branch on this project.")
          when :remove_protected_branches
            build_status_object(false, "You are not allowed to deleted protected branches from this project.")
          when :push_code_to_protected_branches
            build_status_object(false, "You are not allowed to push code to protected branches on this project.")
          when :admin_project
            build_status_object(false, "You are not allowed to change existing tags on this project.")
          else # :push_code
            build_status_object(false, "You are not allowed to push code to this project.")
          end
        return status
      end

      # Return build_status_object(true) if all git hook checks passed successfully
      # or build_status_object(false) if any hook fails
      git_hook_check(user, project, ref, oldrev, newrev)
    end

    def forced_push?(oldrev, newrev)
      Gitlab::ForcePushCheck.force_push?(project, oldrev, newrev)
    end

    def git_hook_check(user, project, ref, oldrev, newrev)
      return build_status_object(true) unless project.git_hook

      return build_status_object(true) unless newrev && oldrev

      git_hook = project.git_hook

      # Prevent tag removal
      if Gitlab::Git.tag_ref?(ref)
        if git_hook.deny_delete_tag && protected_tag?(tag_name(ref)) && Gitlab::Git.blank_ref?(newrev)
          return build_status_object(false, "You can not delete tag")
        end
      else
        # Check commit messages unless its branch removal
        if git_hook.commit_validation? && !Gitlab::Git.blank_ref?(newrev)
          if Gitlab::Git.blank_ref?(oldrev)
            oldrev = project.default_branch
          end

          commits = project.repository.commits_between(oldrev, newrev)
          commits.each do |commit|
            if git_hook.commit_message_regex.present?
              unless commit.safe_message =~ Regexp.new(git_hook.commit_message_regex)
                return build_status_object(false, "Commit message does not follow the pattern")
              end
            end

            if git_hook.author_email_regex.present?
              unless commit.committer_email =~ Regexp.new(git_hook.author_email_regex)
                return build_status_object(false, "Commiter's email does not follow the pattern")
              end

              unless commit.author_email =~ Regexp.new(git_hook.author_email_regex)
                return build_status_object(false, "Author's email does not follow the pattern")
              end
            end

            # Check whether author is a GitLab member
            if git_hook.member_check
              unless User.existing_member?(commit.author_email)
                return build_status_object(false, "Author is not a member of team")
              end

              if commit.author_email != commit.committer_email
                unless User.existing_member?(commit.committer_email)
                  return build_status_object(false, "Commiter is not a member of team")
                end
              end
            end

            if git_hook.file_name_regex.present?
              commit.diffs.each do |diff|
                if (diff.renamed_file || diff.new_file) && diff.new_path =~ Regexp.new(git_hook.file_name_regex)
                  return build_status_object(false, "File name #{diff.new_path.inspect} does not follow the pattern")
                end
              end
            end

            if git_hook.max_file_size > 0
              commit.diffs.each do |diff|
                next if diff.deleted_file

                blob = project.repository.blob_at(commit.id, diff.new_path)
                if blob.size > git_hook.max_file_size.megabytes
                  return build_status_object(false, "File #{diff.new_path.inspect} is larger than the allowed size of #{git_hook.max_file_size} MB")
                end
              end
            end
          end
        end
      end

      build_status_object(true)
    end

    private

    def protected_branch_action(oldrev, newrev, branch_name)
      # we dont allow force push to protected branch
      if forced_push?(oldrev, newrev)
        :force_push_code_to_protected_branches
      elsif Gitlab::Git.blank_ref?(newrev)
        # and we dont allow remove of protected branch
        :remove_protected_branches
      elsif project.developers_can_push_to_protected_branch?(branch_name)
        :push_code
      else
        :push_code_to_protected_branches
      end
    end

    def protected_tag?(tag_name)
      project.repository.tag_names.include?(tag_name)
    end

    def user_allowed?
      Gitlab::UserAccess.allowed?(user)
    end

    def branch_name(ref)
      ref = ref.to_s
      if Gitlab::Git.branch_ref?(ref)
        Gitlab::Git.ref_name(ref)
      else
        nil
      end
    end

    def tag_name(ref)
      ref = ref.to_s
      if Gitlab::Git.tag_ref?(ref)
        Gitlab::Git.ref_name(ref)
      else
        nil
      end
    end

    protected

    def build_status_object(status, message = '')
      GitAccessStatus.new(status, message)
    end

    def git_annex_access_check(project, changes)
      unless user && user_allowed?
        return build_status_object(false, "You don't have access")
      end

      unless project.repository.exists?
        return build_status_object(false, "Repository does not exist")
      end

      if user.can?(:push_code, project)
        build_status_object(true)
      else
        build_status_object(false, "You don't have permission")
      end
    end
  end
end
