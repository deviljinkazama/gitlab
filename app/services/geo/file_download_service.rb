module Geo
  class FileDownloadService
    attr_reader :object_type, :object_id

    LEASE_TIMEOUT = 8.hours.freeze

    def initialize(object_type, object_id)
      @object_type = object_type
      @object_id = object_id
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
    end

    private

    def try_obtain_lease
      uuid = Gitlab::ExclusiveLease.new(lease_key, timeout: LEASE_TIMEOUT).try_obtain

      return unless uuid.present?

      yield

      Gitlab::ExclusiveLease.cancel(lease_key, uuid)
    end

    def download_lfs_object
      lfs_object = LfsObject.find_by_id(object_id)

      return unless lfs_object.present?

      transfer = ::Gitlab::Geo::LfsTransfer.new(lfs_object)
      bytes_downloaded = transfer.download_from_primary

      success = bytes_downloaded && bytes_downloaded >= 0
      update_registry(bytes_downloaded) if success

      success
    end

    def log(message)
      Rails.logger.info "#{self.class.name}: #{message}"
    end

    def update_registry(bytes_downloaded)
      transfer = Geo::FileRegistry.find_or_create_by(
        file_type: object_type,
        file_id: object_id,
        bytes: bytes_downloaded
      )
      transfer.save
    end

    def lease_key
      "file_download_service:#{object_type}:#{object_id}"
    end
  end
end
