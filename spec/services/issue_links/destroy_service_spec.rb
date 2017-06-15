require 'spec_helper'

describe IssueLinks::DestroyService, service: true do
  describe '#execute' do
    let(:project) { create :empty_project }
    let(:user) { create :user }

    subject { described_class.new(issue_link, user).execute }

    context 'success' do
      let(:issue_a) { create :issue, project: project }
      let(:issue_b) { create :issue, project: project }

      let!(:issue_link) { create :issue_link, source: issue_a, target: issue_b }

      before do
        project.add_reporter(user)
      end

      it 'removes related issue' do
        expect { subject }.to change(IssueLink, :count).from(1).to(0)
      end

      it 'creates notes' do
        # Two-way notes creation
        expect(SystemNoteService).to receive(:unrelate_issue)
                                       .with(issue_link.source, issue_link.target, user)
        expect(SystemNoteService).to receive(:unrelate_issue)
                                       .with(issue_link.target, issue_link.source, user)

        subject
      end

      it 'returns success message' do
        is_expected.to eq(message: 'Relation was removed', status: :success)
      end
    end

    context 'failure' do
      let(:unauthorized_project) { create :empty_project }
      let(:issue_a) { create :issue, project: project }
      let(:issue_b) { create :issue, project: unauthorized_project }

      let!(:issue_link) { create :issue_link, source: issue_a, target: issue_b }

      it 'does not remove relation' do
        expect { subject }.not_to change(IssueLink, :count).from(1)
      end

      it 'does not create notes' do
        expect(SystemNoteService).not_to receive(:unrelate_issue)
      end

      it 'returns error message' do
        is_expected.to eq(message: 'Unauthorized', status: :error, http_status: 401)
      end
    end
  end
end
