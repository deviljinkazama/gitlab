require 'rails_helper'

describe 'Dropdown weight', js: true, feature: true do
  include FilteredSearchHelpers

  let!(:project) { create(:empty_project) }
  let!(:user) { create(:user) }
  let(:filtered_search) { find('.filtered-search') }
  let(:js_dropdown_weight) { '#js-dropdown-weight' }

  def send_keys_to_filtered_search(input)
    input.split("").each do |i|
      filtered_search.send_keys(i)
      sleep 3
      wait_for_requests
    end
  end

  def click_weight(text)
    find('#js-dropdown-weight .filter-dropdown .filter-dropdown-item', text: text).click
  end

  def click_static_weight(text)
    find('#js-dropdown-weight .filter-dropdown-item', text: text).click
  end

  before do
    project.team << [user, :master]
    login_as(user)
    create(:issue, project: project)

    visit namespace_project_issues_path(project.namespace, project)
  end

  describe 'behavior' do
    it 'opens when the search bar has weight:' do
      filtered_search.set('weight:')

      expect(page).to have_css(js_dropdown_weight, visible: true)
    end

    it 'closes when the search bar is unfocused' do
      filtered_search.set('weight:')
      find('body').click()

      expect(page).to have_css(js_dropdown_weight, visible: false)
    end

    it 'should load all the weights when opened' do
      send_keys_to_filtered_search('weight:')

      expect(page.all('#js-dropdown-weight .filter-dropdown .filter-dropdown-item').size).to eq(9)
    end
  end

  describe 'selecting from dropdown' do
    before do
      input_filtered_search('weight:', submit: false)
    end

    it 'fills in weight 1' do
      click_weight(1)

      expect(page).to have_css(js_dropdown_weight, visible: false)
      expect_tokens([{ name: 'weight', value: '1' }])
      expect_filtered_search_input_empty
    end

    it 'fills in weight 2' do
      click_weight(2)

      expect(page).to have_css(js_dropdown_weight, visible: false)
      expect_tokens([{ name: 'weight', value: '2' }])
      expect_filtered_search_input_empty
    end

    it 'fills in weight 3' do
      click_weight(3)

      expect(page).to have_css(js_dropdown_weight, visible: false)
      expect_tokens([{ name: 'weight', value: '3' }])
      expect_filtered_search_input_empty
    end

    it 'fills in `no weight`' do
      click_static_weight('No Weight')

      expect(page).to have_css(js_dropdown_weight, visible: false)
      expect_tokens([{ name: 'weight', value: 'none' }])
      expect_filtered_search_input_empty
    end
  end

  describe 'input has existing content' do
    it 'opens weight dropdown with existing search term' do
      filtered_search.set('searchTerm weight:')

      expect(page).to have_css(js_dropdown_weight, visible: true)
    end

    it 'opens weight dropdown with existing assignee' do
      filtered_search.set('assignee:@user weight:')

      expect(page).to have_css(js_dropdown_weight, visible: true)
    end

    it 'opens weight dropdown with existing label' do
      filtered_search.set('label:~bug weight:')

      expect(page).to have_css(js_dropdown_weight, visible: true)
    end

    it 'opens weight dropdown with existing milestone' do
      filtered_search.set('milestone:%v1.0 weight:')

      expect(page).to have_css(js_dropdown_weight, visible: true)
    end
  end
end
