module Gitlab
  module Geo
    OauthApplicationUndefinedError = Class.new(StandardError)

    def self.current_node
      self.cache_value(:geo_node_current) do
        GeoNode.find_by(host: Gitlab.config.gitlab.host,
                        port: Gitlab.config.gitlab.port,
                        relative_url_root: Gitlab.config.gitlab.relative_url_root)
      end
    end

    def self.primary_node
      self.cache_value(:geo_primary_node) { GeoNode.find_by(primary: true) }
    end

    def self.secondary_nodes
      self.cache_value(:geo_secondary_nodes) { GeoNode.where(primary: false) }
    end

    def self.enabled?
      self.cache_value(:geo_node_enabled) { self.connected_to_primary_db? && GeoNode.exists? }
    end

    def self.license_allows?
      ::License.current && ::License.current.add_on?('GitLab_Geo')
    end

    def self.primary?
      self.cache_value(:geo_node_primary) { self.enabled? && self.current_node && self.current_node.primary? }
    end

    def self.secondary?
      self.cache_value(:geo_node_secondary) { self.enabled? && self.current_node && self.current_node.secondary? }
    end

    def self.primary_ssh_path_prefix
      self.cache_value(:geo_primary_ssh_path_prefix) { self.enabled? && self.primary_node && "git@#{self.primary_node.host}:" }
    end

    def self.geo_node?(host:, port:)
      GeoNode.where(host: host, port: port).exists?
    end

    def self.notify_wiki_update(project)
      ::Geo::EnqueueWikiUpdateService.new(project).execute
    end

    def self.bulk_notify_job
      Sidekiq::Cron::Job.find('geo_bulk_notify_worker')
    end

    def self.backfill_job
      Sidekiq::Cron::Job.find('geo_backfill_worker')
    end

    def self.oauth_authentication
      return false unless Gitlab::Geo.secondary?

      self.cache_value(:geo_oauth_application) do
        Gitlab::Geo.current_node.oauth_application || raise(OauthApplicationUndefinedError)
      end
    end

    def self.cache_value(key, &block)
      return yield unless RequestStore.active?

      RequestStore.fetch(key) { yield }
    end

    def self.connected_to_primary_db?
      ActiveRecord::Base.connection.active? &&
        ActiveRecord::Base.connection.table_exists?(GeoNode.table_name)
    end
  end
end
