require 'spec_helper'

describe Gitlab::UsageData do
  let!(:project) { create(:empty_project) }
  let!(:project2) { create(:empty_project) }
  let!(:board) { create(:board, project: project) }

  describe '#data' do
    subject { described_class.data }

    it "gathers usage data" do
      expect(subject.keys).to match_array(%i(
        active_user_count
        counts
        historical_max_users
        license_add_ons
        license_expires_at
        license_starts_at
        license_user_count
        licensee
        license_md5
        recorded_at
        mattermost_enabled
        edition
        version
        uuid
        hostname
      ))
    end

    it "gathers usage counts" do
      count_data = subject[:counts]

      expect(count_data[:boards]).to eq(1)
      expect(count_data[:projects]).to eq(2)

      expect(count_data.keys).to match_array(%i(
        boards
        ci_builds
        ci_pipelines
        ci_runners
        ci_triggers
        ci_pipeline_schedules
        deploy_keys
        deployments
        environments
        geo_nodes
        groups
        issues
        keys
        labels
        ldap_group_links
        ldap_keys
        ldap_users
        lfs_objects
        merge_requests
        milestones
        notes
        projects
        projects_prometheus_active
        pages_domains
        protected_branches
        releases
        remote_mirrors
        services
        snippets
        todos
        uploads
        web_hooks
      ))
    end
  end

  describe '#license_usage_data' do
    subject { described_class.license_usage_data }

    it "gathers license data" do
      license = ::License.current

      expect(subject[:uuid]).to eq(current_application_settings.uuid)
      expect(subject[:license_md5]).to eq(Digest::MD5.hexdigest(license.data))
      expect(subject[:version]).to eq(Gitlab::VERSION)
      expect(subject[:licensee]).to eq(license.licensee)
      expect(subject[:active_user_count]).to eq(User.active.count)
      expect(subject[:licensee]).to eq(license.licensee)
      expect(subject[:license_user_count]).to eq(license.restricted_user_count)
      expect(subject[:license_starts_at]).to eq(license.starts_at)
      expect(subject[:license_expires_at]).to eq(license.expires_at)
      expect(subject[:license_add_ons]).to eq(license.add_ons)
      expect(subject[:recorded_at]).to be_a(Time)
    end
  end

  describe '.service_desk_counts' do
    subject { described_class.service_desk_counts }

    let!(:project3) { create(:empty_project, service_desk_enabled: true) }
    let!(:project4) { create(:empty_project, service_desk_enabled: true) }

    context 'when Service Desk is disabled' do
      it 'returns an empty hash' do
        allow_any_instance_of(License).to receive(:feature_available?).with(:service_desk).and_return(false)

        expect(subject).to eq({})
      end
    end

    context 'when there is no license' do
      it 'returns an empty hash' do
        allow(License).to receive(:current).and_return(nil)

        expect(subject).to eq({})
      end
    end

    context 'when Service Desk is enabled' do
      it 'gathers Service Desk data' do
        create_list(:issue, 3, confidential: true, author: User.support_bot, project: [project3, project4].sample)
        allow_any_instance_of(License).to receive(:feature_available?).with(:service_desk).and_return(true)

        expect(subject).to eq(service_desk_enabled_projects: 2,
                              service_desk_issues: 3)
      end
    end
  end
end
