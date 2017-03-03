module Gitlab
  # The SidekiqStatus module and its child classes can be used for checking if a
  # Sidekiq job has been processed or not.
  #
  # To check if a job has been completed, simply pass the job ID to the
  # `completed?` method:
  #
  #     job_id = SomeWorker.perform_async(...)
  #
  #     if Gitlab::SidekiqStatus.completed?(job_id)
  #       ...
  #     end
  #
  # For each job ID registered a separate key is stored in Redis, making lookups
  # much faster than using Sidekiq's built-in job finding/status API. These keys
  # expire after a certain period of time to prevent storing too many keys in
  # Redis.
  module SidekiqStatus
    STATUS_KEY = 'gitlab-sidekiq-status:%s'.freeze

    # The default time (in seconds) after which a status key is expired
    # automatically. The default of 30 minutes should be more than sufficient
    # for most jobs.
    DEFAULT_EXPIRATION = 30.minutes.to_i

    # Starts tracking of the given job.
    #
    # jid - The Sidekiq job ID
    # expire - The expiration time of the Redis key.
    def self.set(jid, expire = DEFAULT_EXPIRATION)
      Sidekiq.redis do |redis|
        redis.set(key_for(jid), 1, ex: expire)
      end
    end

    # Stops the tracking of the given job.
    #
    # jid - The Sidekiq job ID to remove.
    def self.unset(jid)
      Sidekiq.redis do |redis|
        redis.del(key_for(jid))
      end
    end

    # Returns true if all the given job have been completed.
    #
    # jids - The Sidekiq job IDs to check.
    #
    # Returns true or false.
    def self.all_completed?(jids)
      self.num_running(jids).zero?
    end

    # Returns the number of jobs that are running.
    #
    # jids - The Sidekiq job IDs to check.
    def self.num_running(jids)
      responses = self.job_status(jids)

      responses.select { |value| value }.count
    end

    # Returns the number of jobs that have completed.
    #
    # jids - The Sidekiq job IDs to check.
    def self.num_completed(jids)
      jids.size - self.num_running(jids)
    end

    # Returns the job status for each of the given job IDs.
    #
    # jids - The Sidekiq job IDs to check.
    #
    # Returns an array of true or false indicating job completion.
    def self.job_status(jids)
      keys = jids.map { |jid| key_for(jid) }

      Sidekiq.redis do |redis|
        redis.pipelined do
          keys.each { |key| redis.exists(key) }
        end
      end
    end

    def self.key_for(jid)
      STATUS_KEY % jid
    end
  end
end
