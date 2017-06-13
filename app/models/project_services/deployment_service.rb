# Base class for deployment services
#
# These services integrate with a deployment solution like Kubernetes/OpenShift,
# Mesosphere, etc, to provide additional features to environments.
class DeploymentService < Service
  default_value_for :category, 'deployment'

  def self.supported_events
    %w()
  end

  def predefined_variables
    []
  end

  # Environments may have a number of terminals. Should return an array of
  # hashes describing them, e.g.:
  #
  #     [{
  #       :selectors    => {"a" => "b", "foo" => "bar"},
  #       :url          => "wss://external.example.com/exec",
  #       :headers      => {"Authorization" => "Token xxx"},
  #       :subprotocols => ["foo"],
  #       :ca_pem       => "----BEGIN CERTIFICATE...", # optional
  #       :created_at   => Time.now.utc
  #     }]
  #
  # Selectors should be a set of values that uniquely identify a particular
  # terminal
  def terminals(environment)
    raise NotImplementedError
  end

<<<<<<< HEAD
  # Environments have a rollout status. This represents the current state of
  # deployments to that environment.
  def rollout_status(environment)
    raise NotImplementedError
=======
  def can_test?
    false
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
  end
end
