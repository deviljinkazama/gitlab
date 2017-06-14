require 'spec_helper'

describe WikiPages::DestroyService, services: true do
  let(:project) { create(:empty_project) }
<<<<<<< HEAD
  let(:user)    { create(:user) }
  let(:page)    { create(:wiki_page) }
=======
  let(:user) { create(:user) }
  let(:page) { create(:wiki_page) }
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81

  subject(:service) { described_class.new(project, user) }

  before do
<<<<<<< HEAD
    project.add_master(user)
=======
    project.add_developer(user)
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
  end

  describe '#execute' do
    it 'executes webhooks' do
<<<<<<< HEAD
      expect(service).to receive(:execute_hooks).once.with(instance_of(WikiPage), 'delete')
=======
      expect(service).to receive(:execute_hooks).once
        .with(instance_of(WikiPage), 'delete')
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81

      service.execute(page)
    end
  end
end
