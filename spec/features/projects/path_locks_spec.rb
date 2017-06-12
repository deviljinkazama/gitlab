require 'spec_helper'

feature 'Path Locks', feature: true, js: true do
  let(:user) { create(:user) }
  let(:project) { create(:project, namespace: user.namespace) }
  let(:project_tree_path) { namespace_project_tree_path(project.namespace, project, project.repository.root_ref) }

  before do
    allow(project).to receive(:feature_available?).with(:file_lock) { true }

    project.team << [user, :master]
    login_with(user)

    visit project_tree_path
  end

  scenario 'Locking folders' do
    within '.tree-content-holder' do
      click_link "encoding"
    end
    click_link "Lock"
    visit project_tree_path

    expect(page).to have_selector('.fa-lock')
  end

  scenario 'Locking files' do
    page_tree = find('.tree-content-holder')

    within page_tree do
      click_link "VERSION"
    end

    within '.file-actions' do
      click_link "Lock"
    end

    visit project_tree_path

    within page_tree do
      expect(page).to have_selector('.fa-lock')
    end
  end

  scenario 'Unlocking files' do
    within find('.tree-content-holder') do
      click_link "VERSION"
    end

    within '.file-actions' do
      click_link "Lock"

      expect(page).to have_link('Unlock')
    end

    within '.file-actions' do
      click_link "Unlock"

      expect(page).to have_link('Lock')
    end
  end

  scenario 'Managing of lock list' do
    create :path_lock, path: 'encoding', user: user, project: project

    click_link "Locked Files"

    within '.locks' do
      expect(page).to have_content('encoding')

      find('.btn-remove').click

      expect(page).not_to have_content('encoding')
    end
  end
end
