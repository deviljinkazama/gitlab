module Gitlab
  module Mirror
    include Gitlab::CurrentSettings

    # Runs scheduler every minute
    SCHEDULER_CRON = '* * * * *'.freeze
    PULL_CAPACITY_KEY = 'MIRROR_PULL_CAPACITY'.freeze
    UPPER_JITTER = 1.minute

    class << self
      def configure_cron_job!
        destroy_cron_job!
        return if Gitlab::Geo.secondary?

        Sidekiq::Cron::Job.create(
          name: 'update_all_mirrors_worker',
          cron: SCHEDULER_CRON,
          class: 'UpdateAllMirrorsWorker'
        )
      end

      def max_mirror_capacity_reached?
        available_capacity <= 0
      end

      def threshold_reached?
        available_capacity >= capacity_threshold
      end

      def available_capacity
        current_capacity = Gitlab::Redis.with { |redis| redis.scard(PULL_CAPACITY_KEY) }

        max_capacity - current_capacity.to_i
      end

      def increment_capacity(project_id)
        Gitlab::Redis.with { |redis| redis.sadd(PULL_CAPACITY_KEY, project_id) }
      end

      # We do not want negative capacity
      def decrement_capacity(project_id)
        Gitlab::Redis.with { |redis| redis.srem(PULL_CAPACITY_KEY, project_id) }
      end

      def max_delay
        current_application_settings.mirror_max_delay.hours + rand(UPPER_JITTER)
      end

      def max_capacity
        current_application_settings.mirror_max_capacity
      end

      def capacity_threshold
        current_application_settings.mirror_capacity_threshold
      end

      private

      def update_all_mirrors_cron_job
        Sidekiq::Cron::Job.find("update_all_mirrors_worker")
      end

      def destroy_cron_job!
        update_all_mirrors_cron_job&.destroy
      end
    end
  end
end
