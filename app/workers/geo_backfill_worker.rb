class GeoBackfillWorker
  include Sidekiq::Worker
  include CronjobQueue

  RUN_TIME = 5.minutes.to_i.freeze
  BATCH_SIZE = 100.freeze

  def perform
    return unless Gitlab::Geo.primary_node.present?

    start_time  = Time.now
    project_ids = find_project_ids

    logger.info "Started Geo backfilling for #{project_ids.length} project(s)"

    project_ids.each do |project_id|
      begin
        break if over_time?(start_time)
        break unless Gitlab::Geo.current_node_enabled?

        project = Project.find(project_id)
        next if synced?(project)

        # We try to obtain a lease here for the entire backfilling process
        # because backfill the repositories continuously at a controlled rate
        # instead of hammering the primary node. Initially, we are backfilling
        # one repo at a time. If we don't obtain the lease here, every 5
        # minutes all of 100 projects will be synced.
        try_obtain_lease do |lease|
          Geo::RepositoryBackfillService.new(project_id).execute
        end
      rescue ActiveRecord::RecordNotFound
        logger.error("Couldn't find project with ID=#{project_id}, skipping syncing")
        next
      end
    end

    logger.info "Finished Geo backfilling for #{project_ids.length} project(s)"
  end

  private

  def find_project_ids
    Project.where.not(id: Geo::ProjectRegistry.pluck(:project_id))
           .limit(BATCH_SIZE)
           .pluck(:id)
  end

  def over_time?(start_time)
    Time.now - start_time >= RUN_TIME
  end

  def synced?(project)
    project.repository_exists? || registry_exists?(project)
  end

  def registry_exists?(project)
    Geo::ProjectRegistry.where(project_id: project.id)
                        .where.not(last_repository_synced_at: nil)
                        .any?
  end

  def try_obtain_lease
    lease = Gitlab::ExclusiveLease.new(lease_key, timeout: lease_timeout).try_obtain

    return unless lease

    begin
      yield lease
    ensure
      Gitlab::ExclusiveLease.cancel(lease_key, lease)
    end
  end

  def lease_key
    Geo::RepositoryBackfillService::LEASE_KEY_PREFIX
  end

  def lease_timeout
    Geo::RepositoryBackfillService::LEASE_TIMEOUT
  end

  def node_enabled?
    # No caching of the enabled! If we cache it and an admin disables
    # this node, an active GeoBackfillWorker would keep going for up
    # to max run time after the node was disabled.
    Gitlab::Geo.current_node.reload.enabled?
  end
end
