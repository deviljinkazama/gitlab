class GeoFileDownloadDispatchWorker
  include Sidekiq::Worker
  include CronjobQueue

  LEASE_TIMEOUT = 8.hours.freeze
  BATCH_SIZE = 10

  def perform
    byebug
    return unless Gitlab::Geo.primary_node.present?

    # Multiple Sidekiq workers could be attempted to schedule downloads
    try_obtain_lease(scheduler_lease_key) do
      schedule_lfs_downloads
    end
  end

  private

  def schedule_lfs_downloads
    find_lfs_object_ids.each do |lfs_id|
      key = download_lease_key(:lfs, lfs_id)
      # Avoid downloading the same file simultaneously
      try_obtain_lease(key) do |lease|
        GeoFileDownloadWorker.perform_async(:lfs, lfs_id, lease_key, lease_uuid)
      end
    end
  end

  def find_lfs_object_ids
    LfsObject.where.not(id: Geo::FileTransfer.where(file_type: 'lfs').pluck(:file_id))
      .limit(BATCH_SIZE)
      .pluck(:id)
  end

  def try_obtain_lease(key)
    uuid = Gitlab::ExclusiveLease.new(key, timeout: LEASE_TIMEOUT).try_obtain

    return unless uuid

    yield

    release_lease(key, uuid)
  end

  def try_obtain_download_lease(object_type, object_id)
    key = download_lease_key(object_type, object_id)
    try_obtain(key)
  end

  def scheduler_lease_key
    "geo_file_transfer_dispatch_worker"
  end

  def release_lease(key, uuid)
    Gitlab::ExclusiveLease.cancel(key, uuid)
  end

  def download_lease_key(object_type, object_id)
    "geo_file_traonsfer_dispatch_worker:#{object_type}:#{object_id}"
  end

  def node_enabled?
    Gitlab::Geo.current_node_enabled?
  end
end
