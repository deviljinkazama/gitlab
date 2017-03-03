class GeoFileDownloadWorker
  include Sidekiq::Worker
  include GeoQueue

  def perform(object_type, object_id, lease_key, lease_uuid)
    Geo::FileDownloadService.new(object_type.to_sym, object_id, lease_key, lease_uuid).execute
  end
end
