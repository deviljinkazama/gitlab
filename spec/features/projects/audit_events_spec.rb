require 'spec_helper'

feature 'Projects > Audit Events', js: true, feature: true do
  let(:user) { create(:user) }
  let(:pete) { create(:user, name: 'Pete') }
  let(:project) { create(:project, namespace: user.namespace) }

  before do
    project.team << [user, :master]
    gitlab_sign_in(user)
  end

  describe 'adding an SSH key' do
    it "appears in the project's audit events" do
      visit new_namespace_project_deploy_key_path(project.namespace, project)

      fill_in 'deploy_key_title', with: 'laptop'
      fill_in 'deploy_key_key', with: 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAzrEJUIR6Y03TCE9rIJ+GqTBvgb8t1jI9h5UBzCLuK4VawOmkLornPqLDrGbm6tcwM/wBrrLvVOqi2HwmkKEIecVO0a64A4rIYScVsXIniHRS6w5twyn1MD3sIbN+socBDcaldECQa2u1dI3tnNVcs8wi77fiRe7RSxePsJceGoheRQgC8AZ510UdIlO+9rjIHUdVN7LLyz512auAfYsgx1OfablkQ/XJcdEwDNgi9imI6nAXhmoKUm1IPLT2yKajTIC64AjLOnE0YyCh6+7RFMpiMyu1qiOCpdjYwTgBRiciNRZCH8xIedyCoAmiUgkUT40XYHwLuwiPJICpkAzp7Q== user@laptop'

      click_button 'Add key'

      visit namespace_project_audit_events_path(project.namespace, project)

      expect(page).to have_content('Add deploy key')

      visit namespace_project_deploy_keys_path(project.namespace, project)

      accept_confirm do
        click_on 'Remove'
      end

      visit namespace_project_audit_events_path(project.namespace, project)

      expect(page).to have_content('Remove deploy key')
    end
  end

  describe 'changing a user access level' do
    before do
      project.team << [pete, :developer]
    end

    it "appears in the project's audit events" do
      visit namespace_project_settings_members_path(project.namespace, project)

      project_member = project.project_member(pete)

      page.within "#project_member_#{project_member.id}" do
        click_button 'Developer'
        click_link 'Master'
      end

      # This is to avoid a Capybara::Poltergeist::MouseEventFailed error
      find('a[title=Settings]').trigger('click')

      click_link 'Audit Events'

      page.within('table#audits') do
        expect(page).to have_content 'Change access level from developer to master'
        expect(page).to have_content(project.owner.name)
        expect(page).to have_content('Pete')
      end
    end
  end
end
