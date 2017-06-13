RSpec.shared_examples "protected branches > access control > EE" do
  [['merge', ProtectedBranch::MergeAccessLevel], ['push', ProtectedBranch::PushAccessLevel]].each do |git_operation, access_level_class|
    # Need to set a default for the `git_operation` access level that _isn't_ being tested
    other_git_operation = git_operation == 'merge' ? 'push' : 'merge'
    roles = git_operation == 'merge' ? access_level_class.human_access_levels : access_level_class.human_access_levels.except(0)

    let(:users) { create_list(:user, 5) }
    let(:groups) { create_list(:group, 5) }

    before do
      users.each { |user| project.team << [user, :developer] }
      groups.each { |group| project.project_group_links.create(group: group, group_access: Gitlab::Access::DEVELOPER) }
    end

    it "allows creating protected branches that roles, users, and groups can #{git_operation} to" do
      visit namespace_project_protected_branches_path(project.namespace, project)

      set_protected_branch_name('master')
      set_allowed_to(git_operation, users.map(&:name))
      set_allowed_to(git_operation, groups.map(&:name))
      set_allowed_to(git_operation, roles.values)
      set_allowed_to(other_git_operation)

      click_on "Protect"

      within(".protected-branches-list") { expect(page).to have_content('master') }
      expect(ProtectedBranch.count).to eq(1)
      roles.each { |(access_type_id, _)| expect(ProtectedBranch.last.send("#{git_operation}_access_levels".to_sym).map(&:access_level)).to include(access_type_id) }
      users.each { |user| expect(ProtectedBranch.last.send("#{git_operation}_access_levels".to_sym).map(&:user_id)).to include(user.id) }
      groups.each { |group| expect(ProtectedBranch.last.send("#{git_operation}_access_levels".to_sym).map(&:group_id)).to include(group.id) }
    end

    it "allows updating protected branches so that roles and users can #{git_operation} to it" do
      visit namespace_project_protected_branches_path(project.namespace, project)
      set_protected_branch_name('master')
      set_allowed_to('merge')
      set_allowed_to('push')

      click_on "Protect"

      set_allowed_to(git_operation, users.map(&:name), form: ".js-protected-branch-edit-form")
      set_allowed_to(git_operation, groups.map(&:name), form: ".js-protected-branch-edit-form")
      set_allowed_to(git_operation, roles.values, form: ".js-protected-branch-edit-form")

      wait_for_requests

      expect(ProtectedBranch.count).to eq(1)
      roles.each { |(access_type_id, _)| expect(ProtectedBranch.last.send("#{git_operation}_access_levels".to_sym).map(&:access_level)).to include(access_type_id) }
      users.each { |user| expect(ProtectedBranch.last.send("#{git_operation}_access_levels".to_sym).map(&:user_id)).to include(user.id) }
      groups.each { |group| expect(ProtectedBranch.last.send("#{git_operation}_access_levels".to_sym).map(&:group_id)).to include(group.id) }
    end

    it "allows updating protected branches so that roles and users cannot #{git_operation} to it" do
      visit namespace_project_protected_branches_path(project.namespace, project)
      set_protected_branch_name('master')

      users.each { |user| set_allowed_to(git_operation, user.name) }
      roles.each { |(_, access_type_name)| set_allowed_to(git_operation, access_type_name) }
      groups.each { |group| set_allowed_to(git_operation, group.name) }
      set_allowed_to(other_git_operation)

      click_on "Protect"

      users.each { |user| set_allowed_to(git_operation, user.name, form: ".js-protected-branch-edit-form") }
      groups.each { |group| set_allowed_to(git_operation, group.name, form: ".js-protected-branch-edit-form") }
      roles.each { |(_, access_type_name)| set_allowed_to(git_operation, access_type_name, form: ".js-protected-branch-edit-form") }

      wait_for_requests

      expect(ProtectedBranch.count).to eq(1)
      expect(ProtectedBranch.last.send("#{git_operation}_access_levels".to_sym)).to be_empty
    end

    it "prepends selected users that can #{git_operation} to" do
      users = create_list(:user, 21)
      users.each { |user| project.team << [user, :developer] }

      visit namespace_project_protected_branches_path(project.namespace, project)

      # Create Protected Branch
      set_protected_branch_name('master')
      set_allowed_to(git_operation, roles.values)
      set_allowed_to(other_git_operation)

      click_on 'Protect'

      # Update Protected Branch
      within(".protected-branches-list") do
        find(".js-allowed-to-#{git_operation}").click
        find(".dropdown-input-field").set(users.last.name) # Find a user that is not loaded

        expect(page).to have_selector('.dropdown-header', count: 3)

        %w{Roles Groups Users}.each_with_index do |header, index|
          expect(all('.dropdown-header')[index]).to have_content(header)
        end

        wait_for_requests
        click_on users.last.name
        find(".js-allowed-to-#{git_operation}").click # close
      end
      wait_for_requests

      # Verify the user is appended in the dropdown
      find(".protected-branches-list .js-allowed-to-#{git_operation}").click
      expect(page).to have_selector '.dropdown-content .is-active', text: users.last.name

      expect(ProtectedBranch.count).to eq(1)
      roles.each { |(access_type_id, _)| expect(ProtectedBranch.last.send("#{git_operation}_access_levels".to_sym).map(&:access_level)).to include(access_type_id) }
      expect(ProtectedBranch.last.send("#{git_operation}_access_levels".to_sym).map(&:user_id)).to include(users.last.id)
    end
  end

  context 'When updating a protected branch' do
    it 'discards other roles when choosing "No one"' do
      roles = ProtectedBranch::PushAccessLevel.human_access_levels.except(0)
      visit namespace_project_protected_branches_path(project.namespace, project)
      set_protected_branch_name('fix')
      set_allowed_to('merge')
      set_allowed_to('push', roles.values)
      click_on "Protect"
      wait_for_requests

      roles.each do |(access_type_id, _)|
        expect(ProtectedBranch.last.push_access_levels.map(&:access_level)).to include(access_type_id)
      end
      expect(ProtectedBranch.last.push_access_levels.map(&:access_level)).not_to include(0)

      set_allowed_to('push', 'No one', form: '.js-protected-branch-edit-form')

      wait_for_requests

      roles.each do |(access_type_id, _)|
        expect(ProtectedBranch.last.push_access_levels.map(&:access_level)).not_to include(access_type_id)
      end
      expect(ProtectedBranch.last.push_access_levels.map(&:access_level)).to include(0)
    end
  end

  context 'When creating a protected branch' do
    it 'discards other roles when choosing "No one"' do
      roles = ProtectedBranch::PushAccessLevel.human_access_levels.except(0)
      visit namespace_project_protected_branches_path(project.namespace, project)
      set_protected_branch_name('master')
      set_allowed_to('merge')
      set_allowed_to('push', ProtectedBranch::PushAccessLevel.human_access_levels.values) # Last item (No one) should deselect the other ones
      click_on "Protect"
      wait_for_requests

      roles.each do |(access_type_id, _)|
        expect(ProtectedBranch.last.push_access_levels.map(&:access_level)).not_to include(access_type_id)
      end
      expect(ProtectedBranch.last.push_access_levels.map(&:access_level)).to include(0)
    end
  end
end
