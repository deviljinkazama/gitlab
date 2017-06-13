module Members
  class CreateService < BaseService
    DEFAULT_LIMIT = 100

    def initialize(source, current_user, params = {})
      @source = source
      @current_user = current_user
      @params = params
      @error = nil
    end

    def execute
      return error('No users specified.') if params[:user_ids].blank?

      user_ids = params[:user_ids].split(',').uniq

      return error("Too many users specified (limit is #{user_limit})") if
        user_limit && user_ids.size > user_limit

<<<<<<< HEAD
      members = @source.add_users(
        params[:user_ids].split(','),
=======
      @source.add_users(
        user_ids,
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
        params[:access_level],
        expires_at: params[:expires_at],
        current_user: current_user
      )

<<<<<<< HEAD
      members.compact.each do |member|
        AuditEventService.new(@current_user, @source, action: :create)
          .for_member(member).security_event
      end

      true
=======
      success
    end

    private

    def user_limit
      limit = params.fetch(:limit, DEFAULT_LIMIT)

      limit && limit < 0 ? nil : limit
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
    end
  end
end
