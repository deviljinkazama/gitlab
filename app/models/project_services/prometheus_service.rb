class PrometheusService < MonitoringService
  include ReactiveCaching

  self.reactive_cache_key = ->(service) { [service.class.model_name.singular, service.project_id] }
  self.reactive_cache_lease_timeout = 30.seconds
  self.reactive_cache_refresh_interval = 30.seconds
  self.reactive_cache_lifetime = 1.minute

  #  Access to prometheus is directly through the API
  prop_accessor :api_url

  with_options presence: true, if: :activated? do
    validates :api_url, url: true
  end

  after_save :clear_reactive_cache!

  def initialize_properties
    if properties.nil?
      self.properties = {}
    end
  end

  def title
    'Prometheus'
  end

  def description
    'Prometheus monitoring'
  end

  def help
    'Retrieves `container_cpu_usage_seconds_total` and `container_memory_usage_bytes` from the configured Prometheus server. An `environment` label is required on each metric to identify the Environment.'
  end

  def self.to_param
    'prometheus'
  end

  def fields
    [
      {
        type: 'text',
        name: 'api_url',
        title: 'API URL',
        placeholder: 'Prometheus API Base URL, like http://prometheus.example.com/'
      }
    ]
  end

  # Check we can connect to the Prometheus API
  def test(*args)
    client.ping

    { success: true, result: 'Checked API endpoint' }
  rescue Gitlab::PrometheusError => err
    { success: false, result: err }
  end

  def metrics(environment)
    with_reactive_cache(environment.slug) do |data|
      data
    end
  end

  # Cache metrics for specific environment
  def calculate_reactive_cache(environment_slug)
    return unless active? && project && !project.pending_delete?

    memory_query = %{sum(container_memory_usage_bytes{container_name="app",environment="#{environment_slug}"})/1024/1024}
    cpu_query = %{sum(rate(container_cpu_usage_seconds_total{container_name="app",environment="#{environment_slug}"}[2m]))}

    {
      success: true,
      metrics: {
        # Memory used in MB
        memory_values: client.query_range(memory_query, start: 8.hours.ago),
        memory_current: client.query(memory_query),
        # CPU Usage rate in cores.
        cpu_values: client.query_range(cpu_query, start: 8.hours.ago),
        cpu_current: client.query(cpu_query)
      },
      last_update: Time.now.utc
    }

  rescue Gitlab::PrometheusError => err
    { success: false, result: err.message }
  end

  def client
    @prometheus ||= Gitlab::Prometheus.new(api_url: api_url)
  end
end
