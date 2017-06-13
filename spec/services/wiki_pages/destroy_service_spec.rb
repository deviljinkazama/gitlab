require 'spec_helper'

describe WikiPages::DestroyService, services: true do
  let(:project) { create(:empty_project) }
<<<<<<< HEAD
  let(:user)    { create(:user) }
  let(:page)    { create(:wiki_page) }
=======
  let(:user) { create(:user) }
  let(:page) { create(:wiki_page) }
>>>>>>> ce/9-3-stable

  subject(:service) { described_class.new(project, user) }

  before do
<<<<<<< HEAD
    project.add_master(user)
=======
    project.add_developer(user)
>>>>>>> ce/9-3-stable
  end

  describe '#execute' do
    it 'executes webhooks' do
<<<<<<< HEAD
      expect(service).to receive(:execute_hooks).once.with(instance_of(WikiPage), 'delete')
=======
      expect(service).to receive(:execute_hooks).once
        .with(instance_of(WikiPage), 'delete')
>>>>>>> ce/9-3-stable

      service.execute(page)
    end
  end
end
