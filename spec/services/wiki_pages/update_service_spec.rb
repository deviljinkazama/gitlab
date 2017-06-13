require 'spec_helper'

describe WikiPages::UpdateService, services: true do
  let(:project) { create(:empty_project) }
<<<<<<< HEAD
  let(:user)    { create(:user) }
  let(:page)    { create(:wiki_page) }
=======
  let(:user) { create(:user) }
  let(:page) { create(:wiki_page) }
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81

  let(:opts) do
    {
      content: 'New content for wiki page',
      format: 'markdown',
      message: 'New wiki message'
    }
  end

  subject(:service) { described_class.new(project, user, opts) }

  before do
<<<<<<< HEAD
    project.add_master(user)
=======
    project.add_developer(user)
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
  end

  describe '#execute' do
    it 'updates the wiki page' do
      updated_page = service.execute(page)

      expect(updated_page).to be_valid
<<<<<<< HEAD
      expect(updated_page).to have_attributes(message: opts[:message], content: opts[:content], format: opts[:format].to_sym)
    end

    it 'executes webhooks' do
      expect(service).to receive(:execute_hooks).once.with(instance_of(WikiPage), 'update')
=======
      expect(updated_page.message).to eq(opts[:message])
      expect(updated_page.content).to eq(opts[:content])
      expect(updated_page.format).to eq(opts[:format].to_sym)
    end

    it 'executes webhooks' do
      expect(service).to receive(:execute_hooks).once
        .with(instance_of(WikiPage), 'update')
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81

      service.execute(page)
    end
  end
end
