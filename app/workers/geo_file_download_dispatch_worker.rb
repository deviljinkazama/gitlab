class GeoFileDownloadDispatchWorker
  include Sidekiq::Worker
  include CronjobQueue

  LEASE_TIMEOUT = 8.hours.freeze
  BATCH_SIZE = 10

  def perform
    return unless Gitlab::Geo.secondary?

    # Prevent multiple Sidekiq workers from attempting to schedule downloads
    try_obtain_lease do
      schedule_lfs_downloads
    end
  end

  private

  def schedule_lfs_downloads
    find_lfs_object_ids.each do |lfs_id|
      GeoFileDownloadWorker.perform_async(:lfs, lfs_id)
    end
  end

  def find_lfs_object_ids
    LfsObject.where.not(id: Geo::FileTransfer.where(file_type: 'lfs').pluck(:file_id))
      .limit(BATCH_SIZE)
      .pluck(:id)
  end

  def try_obtain_lease
    uuid = Gitlab::ExclusiveLease.new(lease_key, timeout: LEASE_TIMEOUT).try_obtain

    return unless uuid

    yield

    release_lease(key, uuid)
  end

  def lease_key
    "geo_file_download_dispatch_worker"
  end

  def release_lease(key, uuid)
    Gitlab::ExclusiveLease.cancel(key, uuid)
  end
end
