require 'uri'

class JenkinsDeprecatedService < CiService
  include ReactiveService

  prop_accessor :project_url
  boolean_accessor :multiproject_enabled
  boolean_accessor :pass_unstable

  validates :project_url, presence: true, if: :activated?

  delegate :execute, to: :service_hook, prefix: nil

  after_save :compose_service_hook, if: :activated?

  def compose_service_hook
    hook = service_hook || build_service_hook
    jenkins_url = project_url.sub(/job\/.*/, '')
    hook.url = jenkins_url + "/gitlab/build_now"
    hook.save
  end

  def title
    'Jenkins CI (Deprecated)'
  end

  def description
    'An extendable open source continuous integration server'
  end

  def help
    'You must have installed GitLab Hook plugin into Jenkins. This service ' \
    'is deprecated. Use "Jenkins CI" service instead.'
  end

  def self.to_param
    'jenkins_deprecated'
  end

  def fields
    [
      { type: 'text', name: 'project_url', placeholder: 'Jenkins project URL like http://jenkins.example.com/job/my-project/' },
      { type: 'checkbox', name: 'multiproject_enabled', title: "Multi-project setup enabled?",
        help: "Multi-project mode is configured in Jenkins Gitlab Hook plugin." },
      { type: 'checkbox', name: 'pass_unstable', title: 'Should unstable builds be treated as passing?',
        help: 'Unstable builds will be treated as passing.' }
    ]
  end

  def multiproject_enabled?
    Gitlab::Utils.to_boolean(self.multiproject_enabled)
  end

  def pass_unstable?
    Gitlab::Utils.to_boolean(self.pass_unstable)
  end

  def build_page(sha, ref = nil)
    if multiproject_enabled? && ref.present?
      URI.encode("#{base_project_url}/#{project.name}_#{ref.tr('/', '_')}/scm/bySHA1/#{sha}").to_s
    else
      "#{project_url}/scm/bySHA1/#{sha}"
    end
  end

  def commit_status(sha, ref = nil)
    with_reactive_cache(sha, ref) {|cached| cached[:commit_status] }
  end

  # When multi-project is enabled we need to have a different URL. Rather than
  # relying on the user to provide the proper URL depending on multi-project
  # we just parse the URL and make sure it's how we want it.
  def base_project_url
    url = URI.parse(project_url)
    URI.join(url, '/job').to_s
  end

  def calculate_reactive_cache(sha, ref)
    { commit_status: read_commit_status(sha, ref) }
  end

  private

  def read_commit_status(sha, ref)
    parsed_url = URI.parse(build_page(sha, ref))

    if parsed_url.userinfo.blank?
      response = HTTParty.get(build_page(sha, ref), verify: false)
    else
      get_url = build_page(sha, ref).gsub("#{parsed_url.userinfo}@", "")
      auth = {
        username: URI.decode(parsed_url.user),
        password: URI.decode(parsed_url.password)
      }
      response = HTTParty.get(get_url, verify: false, basic_auth: auth)
    end

    if response.code == 200
      # img.build-caption-status-icon for old jenkins version
      src = Nokogiri.parse(response).css('img.build-caption-status-icon,.build-caption>img').first.attributes['src'].value
      if src =~ /blue\.png$/ || (src =~ /yellow\.png/ && pass_unstable?)
        'success'
      elsif src =~ /(red|aborted|yellow)\.png$/
        'failed'
      elsif src =~ /anime\.gif$/
        'running'
      else
        'pending'
      end
    else
      :error
    end
  end
end
