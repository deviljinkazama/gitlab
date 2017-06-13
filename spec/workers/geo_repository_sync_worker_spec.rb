require 'spec_helper'

describe GeoRepositorySyncWorker do
  let!(:primary)   { create(:geo_node, :primary, host: 'primary-geo-node') }
  let!(:secondary) { create(:geo_node, :current) }
  let!(:project_1) { create(:empty_project) }
  let!(:project_2) { create(:empty_project) }

  subject { described_class.new }

  describe '#perform' do
    before do
      allow_any_instance_of(Gitlab::ExclusiveLease).to receive(:try_obtain) { true }
    end

    it 'performs Geo::RepositorySyncService for each project' do
      expect(Geo::RepositorySyncService).to receive(:new).twice.and_return(spy)

      subject.perform
    end

    it 'performs Geo::RepositorySyncService for projects where last attempt to sync failed' do
      Geo::ProjectRegistry.create(
        project: project_1,
        last_repository_synced_at: DateTime.now,
        last_repository_successful_sync_at: nil
      )

      expect(Geo::RepositorySyncService).to receive(:new).twice.and_return(spy)

      subject.perform
    end

    it 'performs Geo::RepositorySyncService for synced projects updated recently' do
      Geo::ProjectRegistry.create(
        project: project_1,
        last_repository_synced_at: 2.days.ago,
        last_repository_successful_sync_at: 2.days.ago
      )

      Geo::ProjectRegistry.create(
        project: project_2,
        last_repository_synced_at: 2.days.ago,
        last_repository_successful_sync_at: 2.days.ago
      )

      project_1.update_attribute(:last_repository_updated_at, 2.days.ago)
      project_2.update_attribute(:last_repository_updated_at, 10.minutes.ago)

      expect(Geo::RepositorySyncService).to receive(:new).once.and_return(spy)

      subject.perform
    end

    it 'does not perform Geo::RepositorySyncService when secondary role is disabled' do
      allow(Gitlab::Geo).to receive(:secondary_role_enabled?) { false }

      expect(Geo::RepositorySyncService).not_to receive(:new)

      subject.perform
    end

    it 'does not perform Geo::RepositorySyncService when primary node does not exists' do
      allow(Gitlab::Geo).to receive(:primary_node) { nil }

      expect(Geo::RepositorySyncService).not_to receive(:new)

      subject.perform
    end

    it 'does not perform Geo::RepositorySyncService when node is disabled' do
      allow_any_instance_of(GeoNode).to receive(:enabled?) { false }

      expect(Geo::RepositorySyncService).not_to receive(:new)

      subject.perform
    end

    it 'does not perform Geo::RepositorySyncService when can not obtain a lease' do
      allow_any_instance_of(Gitlab::ExclusiveLease).to receive(:try_obtain) { false }

      expect(Geo::RepositorySyncService).not_to receive(:new)

      subject.perform
    end
  end
end
