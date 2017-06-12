require 'spec_helper'

describe Project, elastic: true do
  before do
    stub_application_setting(elasticsearch_search: true, elasticsearch_indexing: true)
    Gitlab::Elastic::Helper.create_empty_index
  end

  after do
    Gitlab::Elastic::Helper.delete_index
    stub_application_setting(elasticsearch_search: false, elasticsearch_indexing: false)
  end

  it "finds projects" do
    project_ids = []

    Sidekiq::Testing.inline! do
      project = create :empty_project, name: 'test1'
      project1 = create :empty_project, path: 'test2', description: 'awesome project'
      project2 = create :empty_project
      create :empty_project, path: 'someone_elses_project'
      project_ids += [project.id, project1.id, project2.id]

      Gitlab::Elastic::Helper.refresh_index
    end

    expect(described_class.elastic_search('test1', options: { project_ids: project_ids }).total_count).to eq(1)
    expect(described_class.elastic_search('test2', options: { project_ids: project_ids }).total_count).to eq(1)
    expect(described_class.elastic_search('awesome', options: { project_ids: project_ids }).total_count).to eq(1)
    expect(described_class.elastic_search('test*', options: { project_ids: project_ids }).total_count).to eq(2)
    expect(described_class.elastic_search('someone_elses_project', options: { project_ids: project_ids }).total_count).to eq(0)
  end

  it "finds partial matches in project names" do
    project_ids = []

    Sidekiq::Testing.inline! do
      project = create :empty_project, name: 'tesla-model-s'
      project1 = create :empty_project, name: 'tesla_model_s'
      project_ids += [project.id, project1.id]

      Gitlab::Elastic::Helper.refresh_index
    end

    expect(described_class.elastic_search('tesla', options: { project_ids: project_ids }).total_count).to eq(2)
  end

  it "returns json with all needed elements" do
    project = create :empty_project

    expected_hash = project.attributes.extract!(
      'id',
      'name',
      'path',
      'description',
      'namespace_id',
      'created_at',
      'archived',
      'updated_at',
      'visibility_level',
      'last_activity_at'
    )

    expected_hash.merge!(
      project.project_feature.attributes.extract!(
        'issues_access_level',
        'merge_requests_access_level',
        'snippets_access_level',
        'wiki_access_level',
        'repository_access_level'
      )
    )

    expected_hash['name_with_namespace'] = project.name_with_namespace
    expected_hash['path_with_namespace'] = project.path_with_namespace

    expect(project.as_indexed_json).to eq(expected_hash)
  end
end
