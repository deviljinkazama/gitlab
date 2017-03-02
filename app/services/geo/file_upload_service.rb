module Geo
  class FileUploadService
    IAT_LEEWAY = 60.seconds.to_i

    attr_reader :params, :auth_header

    def initialize(params, auth_header)
      @params = params
      @auth_header = auth_header
    end

    def execute
      # Returns { code: :ok, file: CarrierWave File object } upon success
      data = ::Gitlab::Geo::JwtRequestDecoder.new(auth_header).decode

      return unless data.present?

      response =
        case params[:type]
        when 'lfs'
          handle_lfs_geo_request(params[:id], data)
        else
          {}
        end

      response
    end

    def handle_lfs_geo_request(id, message)
      status = { code: :not_found, message: 'LFS object not found' }
      lfs_object = LfsObject.find(id)

      return status unless lfs_object.present?

      if message[:sha256] != lfs_object.oid
        return status
      end

      unless lfs_object.file.present? && lfs_object.file.exists?
        status[:message] = "LFS object does not have a file"
        return status
      end

      status[:code] = :ok
      status[:message] = "Success"
      status[:file] = lfs_object.file
      status
    end
  end
end
