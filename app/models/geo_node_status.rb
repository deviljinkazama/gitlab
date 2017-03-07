class GeoNodeStatus
  include ActiveModel::Model

  attr_writer :health

  def health
    @health ||= HealthCheck::Utils.process_checks(['geo'])
  end

  def healthy?
    health.blank?
  end

  def repositories_count
    @repositories_count ||= Project.count
  end

  def repositories_count=(value)
    @repositories_count = value.to_i
  end

  def repositories_synced_count
    @repositories_synced_count ||= Geo::ProjectRegistry.synced.count
  end

  def repositories_synced_count=(value)
    @repositories_synced_count = value.to_i
  end

  def repositories_synced_in_percentage
    sync_percentage(repositories_count, repositories_synced_count)
  end

  def repositories_failed_count
    @repositories_failed_count ||= Geo::ProjectRegistry.failed.count
  end

  def repositories_failed_count=(value)
    @repositories_failed_count = value.to_i
  end

  def lfs_objects_total
    @lfs_objects_total ||= LfsObject.count
  end

  def lfs_objects_total=(value)
    @lfs_objects_total = value.to_i
  end

  def lfs_objects_synced
    @lfs_objects_synced ||= Geo::FileRegistry.where(file_type: :lfs).count
  end

  def lfs_objects_synced=(value)
    @lfs_objects_synced = value.to_i
  end

  def lfs_objects_synced_in_percentage
    sync_percentage(lfs_objects_total, lfs_objects_synced)
  end

  private

  def sync_percentage(total, synced)
    return 0 if total.zero?

    (synced.to_f / total.to_f) * 100.0
  end
end
