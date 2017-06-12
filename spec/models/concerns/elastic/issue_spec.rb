require 'spec_helper'

describe Issue, elastic: true do
  before do
    stub_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    Gitlab::Elastic::Helper.create_empty_index
  end

  after do
    Gitlab::Elastic::Helper.delete_index
    stub_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
  end

  let(:project) { create :empty_project }

  it "searches issues" do
    Sidekiq::Testing.inline! do
      create :issue, title: 'bla-bla term1', project: project
      create :issue, description: 'bla-bla term2', project: project
      create :issue, project: project

      # The issue I have no access to
      create :issue, title: 'bla-bla term3'

      Gitlab::Elastic::Helper.refresh_index
    end

    options = { project_ids: [project.id] }

    expect(described_class.elastic_search('(term1 | term2 | term3) +bla-bla', options: options).total_count).to eq(2)
    expect(described_class.elastic_search(Issue.last.to_reference, options: options).total_count).to eq(1)
  end

  it "returns json with all needed elements" do
    assignee = create(:user)
    issue = create :issue, project: project, assignees: [assignee]

    expected_hash = issue.attributes.extract!('id', 'iid', 'title', 'description', 'created_at',
                                                'updated_at', 'state', 'project_id', 'author_id',
                                                'confidential')

    expected_hash['assignee_id'] = [assignee.id]

    expect(issue.as_indexed_json).to eq(expected_hash)
  end
end
