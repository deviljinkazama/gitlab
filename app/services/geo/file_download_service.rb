module Geo
  class FileDownloadService
    attr_reader :object_type, :object_id, :lease_key, :lease_uuid

    LEASE_TIMEOUT = 8.hours.freeze

    def initialize(object_type, object_id, lease_key, lease_uuid)
      @object_type = object_type
      @object_id = object_id
      @lease_key = lease_key
      @lease_uuid = lease_uuid
    end

    def execute
      try_obtain_lease do |lease|
        case object_type
        when :lfs
          download_lfs_object
        else
          log("unknown file type: #{object_type}")
        end
      end
    ensure
      Gitlab::ExclusiveLease.cancel(lease_key, lease_uuid)
    end

    private

    def try_obtain_lease
      download_lease = Gitlab::ExclusiveLease.new(lease_key, timeout: LEASE_TIMEOUT).try_obtain

      return unless download_lease.present?

      yield

      Gitlab::ExclusiveLease.cancel(lease_key, lease_uuid)
    end

    def download_lfs_object
      lfs_object = LfsObject.find(object_id)

      return unless lfs_object.present?

      transfer = ::Gitlab::Geo::LfsTransfer.new(lfs_object)
      bytes_downloaded = transfer.download_from_primary

      update_tracking_db if bytes_downloaded >= 0
    end

    def log(message)
      Rails.logger.info "#{self.class.name}: #{message}"
    end

    def update_tracking_db
      transfer = Geo::FileTransfer.find_or_create_by(
        file_type: object_type,
        file_id: object_id)
      transfer.save
    end
  end
end
