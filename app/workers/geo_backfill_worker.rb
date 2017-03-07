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

        try_obtain_lease do |lease|
          GeoSingleRepositoryBackfillWorker.new.perform(project_id, lease)
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
    return [] if Project.count == Geo::ProjectRegistry.count

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

    yield lease
  end

  def lease_key
    Geo::RepositoryBackfillService::LEASE_KEY_PREFIX
  end

  def lease_timeout
    Geo::RepositoryBackfillService::LEASE_TIMEOUT
  end
end
