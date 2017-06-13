require 'spec_helper'

describe WikiPages::CreateService, services: true do
  let(:project) { create(:empty_project) }
<<<<<<< HEAD
  let(:user)    { create(:user) }
=======
  let(:user) { create(:user) }
>>>>>>> ce/9-3-stable

  let(:opts) do
    {
      title: 'Title',
      content: 'Content for wiki page',
      format: 'markdown'
    }
  end

  subject(:service) { described_class.new(project, user, opts) }

  before do
<<<<<<< HEAD
    project.add_master(user)
=======
    project.add_developer(user)
>>>>>>> ce/9-3-stable
  end

  describe '#execute' do
    it 'creates wiki page with valid attributes' do
      page = service.execute

      expect(page).to be_valid
<<<<<<< HEAD
      expect(page).to have_attributes(title: opts[:title], content: opts[:content], format: opts[:format].to_sym)
    end

    it 'executes webhooks' do
      expect(service).to receive(:execute_hooks).once.with(instance_of(WikiPage), 'create')
=======
      expect(page.title).to eq(opts[:title])
      expect(page.content).to eq(opts[:content])
      expect(page.format).to eq(opts[:format].to_sym)
    end

    it 'executes webhooks' do
      expect(service).to receive(:execute_hooks).once
        .with(instance_of(WikiPage), 'create')
>>>>>>> ce/9-3-stable

      service.execute
    end
  end
end
