require 'spec_helper'

describe GeoFileDownloadDispatchWorker do
  let!(:lfs_object) { create(:lfs_object) }

  before do
    create(:geo_node)
    allow(Gitlab::Geo).to receive(:secondary?).and_return(true)
  end

  describe '#perform' do
    it 'executes GeoFileDownloadWorker if it can get a lease' do
      allow_any_instance_of(Gitlab::ExclusiveLease)
        .to receive(:try_obtain).and_return(true)
      allow_any_instance_of(described_class).to receive(:over_time?).and_return(false, true)
      expect(GeoFileDownloadWorker).to receive(:perform_async).and_call_original
      expect(Gitlab::SidekiqStatus).to receive(:job_status).and_return([])

      Sidekiq::Testing.inline! do
        described_class.new.perform
      end
    end
  end
end
