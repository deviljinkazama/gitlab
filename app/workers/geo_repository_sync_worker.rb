class GeoRepositorySyncWorker
  include Sidekiq::Worker
  include CronjobQueue

  RUN_TIME = 5.minutes.to_i
  BATCH_SIZE = 100
  LAST_SYNC_INTERVAL = 24.hours

  def perform
    return unless Gitlab::Geo.secondary_role_enabled?
    return unless Gitlab::Geo.primary_node.present?

    start_time = Time.now
    project_ids_not_synced = find_project_ids_not_synced
    project_ids_updated_recently = find_project_ids_updated_recently
    project_ids = interleave(project_ids_not_synced, project_ids_updated_recently)

    logger.info "Started Geo repository syncing for #{project_ids.length} project(s)"

    project_ids.each do |project_id|
      begin
        break if over_time?(start_time)
        break unless node_enabled?

        # We try to obtain a lease here for the entire sync process because we
        # want to sync the repositories continuously at a controlled rate
        # instead of hammering the primary node. Initially, we are syncing
        # one repo at a time. If we don't obtain the lease here, every 5
        # minutes all of 100 projects will be synced.
        try_obtain_lease do |lease|
          Geo::RepositorySyncService.new(project_id).execute
        end
      rescue ActiveRecord::RecordNotFound
        logger.error("Couldn't find project with ID=#{project_id}, skipping syncing")
        next
      end
    end

    logger.info "Finished Geo repository syncing for #{project_ids.length} project(s)"
  end

  private

  def find_project_ids_not_synced
    Project.where.not(id: Geo::ProjectRegistry.synced.pluck(:project_id))
           .order(last_repository_updated_at: :desc)
           .limit(BATCH_SIZE)
           .pluck(:id)
  end

  def find_project_ids_updated_recently
    Geo::ProjectRegistry.dirty
                        .order(Gitlab::Database.nulls_first_order(:last_repository_synced_at, :desc))
                        .limit(BATCH_SIZE)
                        .pluck(:project_id)
  end

  def interleave(first, second)
    if first.length >= second.length
      first.zip(second)
    else
      second.zip(first).map(&:reverse)
    end.flatten(1).uniq.compact.take(BATCH_SIZE)
  end

  def over_time?(start_time)
    Time.now - start_time >= RUN_TIME
  end

  def node_enabled?
    # Only check every minute to avoid polling the DB excessively
    unless @last_enabled_check.present? && @last_enabled_check > 1.minute.ago
      @last_enabled_check = Time.now
      @current_node_enabled = nil
    end

    @current_node_enabled ||= Gitlab::Geo.current_node_enabled?
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
    Geo::RepositorySyncService::LEASE_KEY_PREFIX
  end

  def lease_timeout
    Geo::RepositorySyncService::LEASE_TIMEOUT
  end
end
