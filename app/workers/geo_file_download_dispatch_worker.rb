class GeoFileDownloadDispatchWorker
  include Sidekiq::Worker
  include CronjobQueue

  LEASE_KEY = 'geo_file_download_dispatch_worker'.freeze
  LEASE_TIMEOUT = 8.hours.freeze
  RUN_TIME = 60.minutes.to_i.freeze
  BATCH_SIZE = 10

  def initialize
    @scheduled_lfs_jobs = []
  end

  def perform
    return unless Gitlab::Geo.secondary?

    @start_time = Time.now

    # Prevent multiple Sidekiq workers from attempting to schedule downloads
    try_obtain_lease do
      loop do
        break if over_time?
        break unless downloads_remain?

        update_jobs_in_progress
        schedule_lfs_downloads

        sleep(1)
      end
    end
  end

  private

  def over_time?
    Time.now - @start_time >= RUN_TIME
  end

  def downloads_remain?
    find_lfs_object_ids(1).count
  end

  def schedule_lfs_downloads
    num_to_schedule = BATCH_SIZE - job_ids.size

    return if num_to_schedule.zero?

    object_ids = find_lfs_object_ids(num_to_schedule)

    object_ids.each do |lfs_id|
      job_id = GeoFileDownloadWorker.perform_async(:lfs, lfs_id)

      if job_id
        @scheduled_lfs_jobs << { job_id: job_id, id: lfs_id }
      end
    end
  end

  def find_lfs_object_ids(limit)
    downloaded_ids = Geo::FileRegistry.where(file_type: 'lfs').pluck(:file_id)
    downloaded_ids = (downloaded_ids + scheduled_lfs_ids).uniq
    LfsObject.where.not(id: downloaded_ids).limit(limit).pluck(:id)
  end

  def update_jobs_in_progress
    status = Gitlab::SidekiqStatus.job_status(job_ids)

    @scheduled_lfs_jobs = @scheduled_lfs_jobs.zip(status).map{ |x| x[0] if x[1] }.compact
  end

  def job_ids
    @scheduled_lfs_jobs.map{ |data| data[:job_id] }
  end

  def scheduled_lfs_ids
    @scheduled_lfs_jobs.map { |data| data[:id] }
  end

  def try_obtain_lease
    uuid = Gitlab::ExclusiveLease.new(LEASE_KEY, timeout: LEASE_TIMEOUT).try_obtain

    return unless uuid

    yield

    release_lease(uuid)
  end

  def release_lease(uuid)
    Gitlab::ExclusiveLease.cancel(LEASE_KEY, uuid)
  end
end
