module SharedGroup
  include Spinach::DSL

  step 'current user is developer of group "Owned"' do
    is_member_of(current_user.name, "Owned", Gitlab::Access::DEVELOPER)
  end

  step '"John Doe" is owner of group "Owned"' do
    is_member_of("John Doe", "Owned", Gitlab::Access::OWNER)
  end

  step '"John Doe" is guest of group "Guest"' do
    is_member_of("John Doe", "Guest", Gitlab::Access::GUEST)
  end

  step '"Mary Jane" is owner of group "Owned"' do
    is_member_of("Mary Jane", "Owned", Gitlab::Access::OWNER)
  end

  step '"Mary Jane" is guest of group "Owned"' do
    is_member_of("Mary Jane", "Owned", Gitlab::Access::GUEST)
  end

  step '"Mary Jane" is guest of group "Guest"' do
    is_member_of("Mary Jane", "Guest", Gitlab::Access::GUEST)
  end

  step '"Pete Peters" is owner of group "Sourcing"' do
    is_member_of("Pete Peters", "Sourcing", Gitlab::Access::OWNER)
  end

  step 'I should see group "TestGroup"' do
    expect(page).to have_content "TestGroup"
  end

  step 'I should not see group "TestGroup"' do
    expect(page).not_to have_content "TestGroup"
  end

  protected

  def is_member_of(username, groupname, role)
    @project_count ||= 0
    user = User.find_by(name: username) || create(:user, name: username)
    group = Group.find_by(name: groupname) || create(:group, name: groupname)
    group.add_user(user, role)
    project ||= create(:project, :repository, namespace: group, path: "project#{@project_count}")
    create(:closed_issue_event, project: project)
    project.team << [user, :master]
    @project_count += 1
  end

  def owned_group
    @owned_group ||= Group.find_by(name: "Owned")
  end
end
