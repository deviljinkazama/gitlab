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
      expect(GeoFileDownloadWorker).to receive(:perform_async)

      described_class.new.perform
    end
  end
end
