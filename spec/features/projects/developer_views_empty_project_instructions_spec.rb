require 'rails_helper'

feature 'Developer views empty project instructions', feature: true do
  let(:project) { create(:empty_project, :empty_repo) }
  let(:developer) { create(:user) }

  background do
    project.team << [developer, :developer]

    gitlab_sign_in(developer)
  end

  context 'without an SSH key' do
    scenario 'defaults to HTTP' do
      visit_project

      expect_instructions_for('http')
    end

    scenario 'switches to SSH', js: true do
      visit_project

      select_protocol('SSH')

      expect_instructions_for('ssh')
    end
  end

  context 'with an SSH key' do
    background do
      create(:personal_key, user: developer)
    end

    scenario 'defaults to SSH' do
      visit_project

      expect_instructions_for('ssh')
    end

    scenario 'switches to HTTP', js: true do
      visit_project

      select_protocol('HTTP')

      expect_instructions_for('http')
    end
  end

  context 'with Kerberos enabled' do
    background do
      allow(Gitlab.config.kerberos).to receive(:enabled).and_return(true)
    end

    scenario 'defaults to KRB5' do
      visit_project

      expect_instructions_for('kerberos')
    end
  end

  def visit_project
    visit namespace_project_path(project.namespace, project)
  end

  def select_protocol(protocol)
    find('#clone-dropdown').click
    find(".#{protocol.downcase}-selector").click
  end

  def expect_instructions_for(protocol)
    msg = :"#{protocol.downcase}_url_to_repo"

    expect(page).to have_content("git clone #{project.send(msg)}")
  end
end
