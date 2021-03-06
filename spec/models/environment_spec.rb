require 'spec_helper'

describe Environment, models: true do
  set(:project) { create(:empty_project) }
  subject(:environment) { create(:environment, project: project) }

  it { is_expected.to belong_to(:project) }
  it { is_expected.to have_many(:deployments) }

  it { is_expected.to delegate_method(:stop_action).to(:last_deployment) }
  it { is_expected.to delegate_method(:manual_actions).to(:last_deployment) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_uniqueness_of(:name).scoped_to(:project_id) }
  it { is_expected.to validate_length_of(:name).is_at_most(255) }

  it { is_expected.to validate_uniqueness_of(:slug).scoped_to(:project_id) }
  it { is_expected.to validate_length_of(:slug).is_at_most(24) }

  it { is_expected.to validate_length_of(:external_url).is_at_most(255) }
  it { is_expected.to validate_uniqueness_of(:external_url).scoped_to(:project_id) }

  describe '.order_by_last_deployed_at' do
    let(:project) { create(:project) }
    let!(:environment1) { create(:environment, project: project) }
    let!(:environment2) { create(:environment, project: project) }
    let!(:environment3) { create(:environment, project: project) }
    let!(:deployment1) { create(:deployment, environment: environment1) }
    let!(:deployment2) { create(:deployment, environment: environment2) }
    let!(:deployment3) { create(:deployment, environment: environment1) }

    it 'returns the environments in order of having been last deployed' do
      expect(project.environments.order_by_last_deployed_at.to_a).to eq([environment3, environment2, environment1])
    end
  end

  describe 'state machine' do
    it 'invalidates the cache after a change' do
      expect(environment).to receive(:expire_etag_cache)

      environment.stop
    end
  end

  describe '#expire_etag_cache' do
    let(:store) { Gitlab::EtagCaching::Store.new }

    it 'changes the cached value' do
      old_value = store.get(environment.etag_cache_key)

      environment.stop

      expect(store.get(environment.etag_cache_key)).not_to eq(old_value)
    end
  end

  describe '#nullify_external_url' do
    it 'replaces a blank url with nil' do
      env = build(:environment, external_url: "")

      expect(env.save).to be true
      expect(env.external_url).to be_nil
    end
  end

  describe '#includes_commit?' do
    let(:project) { create(:project, :repository) }

    context 'without a last deployment' do
      it "returns false" do
        expect(environment.includes_commit?('HEAD')).to be false
      end
    end

    context 'with a last deployment' do
      let!(:deployment) do
        create(:deployment, environment: environment, sha: project.commit('master').id)
      end

      context 'in the same branch' do
        it 'returns true' do
          expect(environment.includes_commit?(RepoHelpers.sample_commit)).to be true
        end
      end

      context 'not in the same branch' do
        before do
          deployment.update(sha: project.commit('feature').id)
        end

        it 'returns false' do
          expect(environment.includes_commit?(RepoHelpers.sample_commit)).to be false
        end
      end
    end
  end

  describe '#update_merge_request_metrics?' do
    {
      'production' => true,
      'production/eu' => true,
      'production/www.gitlab.com' => true,
      'productioneu' => false,
      'Production' => false,
      'Production/eu' => false,
      'test-production' => false
    }.each do |name, expected_value|
      it "returns #{expected_value} for #{name}" do
        env = create(:environment, name: name)

        expect(env.update_merge_request_metrics?).to eq(expected_value)
      end
    end
  end

  describe '#first_deployment_for' do
    let(:project)       { create(:project, :repository) }
    let!(:deployment)   { create(:deployment, environment: environment, ref: commit.parent.id) }
    let!(:deployment1)  { create(:deployment, environment: environment, ref: commit.id) }
    let(:head_commit)   { project.commit }
    let(:commit)        { project.commit.parent }

    context 'Gitaly find_ref_name feature disabled' do
      it 'returns deployment id for the environment' do
        expect(environment.first_deployment_for(commit)).to eq deployment1
      end

      it 'return nil when no deployment is found' do
        expect(environment.first_deployment_for(head_commit)).to eq nil
      end
    end

    # TODO: Uncomment when feature is reenabled
    # context 'Gitaly find_ref_name feature enabled' do
    #   before do
    #     allow(Gitlab::GitalyClient).to receive(:feature_enabled?).with(:find_ref_name).and_return(true)
    #   end
    #
    #   it 'calls GitalyClient' do
    #     expect_any_instance_of(Gitlab::GitalyClient::Ref).to receive(:find_ref_name)
    #
    #     environment.first_deployment_for(commit)
    #   end
    # end
  end

  describe '#environment_type' do
    subject { environment.environment_type }

    it 'sets a environment type if name has multiple segments' do
      environment.update!(name: 'production/worker.gitlab.com')

      is_expected.to eq('production')
    end

    it 'nullifies a type if it\'s a simple name' do
      environment.update!(name: 'production')

      is_expected.to be_nil
    end
  end

  describe '#stop_action?' do
    subject { environment.stop_action? }

    context 'when no other actions' do
      it { is_expected.to be_falsey }
    end

    context 'when matching action is defined' do
      let(:build) { create(:ci_build) }
      let!(:deployment) { create(:deployment, environment: environment, deployable: build, on_stop: 'close_app') }
      let!(:close_action) { create(:ci_build, :manual, pipeline: build.pipeline, name: 'close_app') }

      context 'when environment is available' do
        before do
          environment.start
        end

        it { is_expected.to be_truthy }
      end

      context 'when environment is stopped' do
        before do
          environment.stop
        end

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '#stop_with_action!' do
    let(:user) { create(:admin) }

    subject { environment.stop_with_action!(user) }

    before do
      expect(environment).to receive(:available?).and_call_original
    end

    context 'when no other actions' do
      context 'environment is available' do
        before do
          environment.update(state: :available)
        end

        it do
          subject

          expect(environment).to be_stopped
        end
      end

      context 'environment is already stopped' do
        before do
          environment.update(state: :stopped)
        end

        it do
          subject

          expect(environment).to be_stopped
        end
      end
    end

    context 'when matching action is defined' do
      let(:pipeline) { create(:ci_pipeline, project: project) }
      let(:build) { create(:ci_build, pipeline: pipeline) }

      let!(:deployment) do
        create(:deployment, environment: environment,
                            deployable: build,
                            on_stop: 'close_app')
      end

      context 'when user is not allowed to stop environment' do
        let!(:close_action) do
          create(:ci_build, :manual, pipeline: pipeline, name: 'close_app')
        end

        it 'raises an exception' do
          expect { subject }.to raise_error(Gitlab::Access::AccessDeniedError)
        end
      end

      context 'when user is allowed to stop environment' do
        before do
          project.add_developer(user)

          create(:protected_branch, :developers_can_merge,
                 name: 'master', project: project)
        end

        context 'when action did not yet finish' do
          let!(:close_action) do
            create(:ci_build, :manual, pipeline: pipeline, name: 'close_app')
          end

          it 'returns the same action' do
            expect(subject).to eq(close_action)
            expect(subject.user).to eq(user)
          end
        end

        context 'if action did finish' do
          let!(:close_action) do
            create(:ci_build, :manual, :success,
                   pipeline: pipeline, name: 'close_app')
          end

          it 'returns a new action of the same type' do
            expect(subject).to be_persisted
            expect(subject.name).to eq(close_action.name)
            expect(subject.user).to eq(user)
          end
        end
      end
    end
  end

  describe 'recently_updated_on_branch?' do
    subject { environment.recently_updated_on_branch?('feature') }

    context 'when last deployment to environment is the most recent one' do
      before do
        create(:deployment, environment: environment, ref: 'feature')
      end

      it { is_expected.to be true }
    end

    context 'when last deployment to environment is not the most recent' do
      before do
        create(:deployment, environment: environment, ref: 'feature')
        create(:deployment, environment: environment, ref: 'master')
      end

      it { is_expected.to be false }
    end
  end

  describe '#actions_for' do
    let(:deployment) { create(:deployment, environment: environment) }
    let(:pipeline) { deployment.deployable.pipeline }
    let!(:review_action) { create(:ci_build, :manual, name: 'review-apps', pipeline: pipeline, environment: 'review/$CI_COMMIT_REF_NAME' )}
    let!(:production_action) { create(:ci_build, :manual, name: 'production', pipeline: pipeline, environment: 'production' )}

    it 'returns a list of actions with matching environment' do
      expect(environment.actions_for('review/master')).to contain_exactly(review_action)
    end
  end

  describe '#deployment_service_ready?' do
    subject { environment.deployment_service_ready? }

    context 'when the enviroment is available' do
      context 'with a deployment service' do
        let(:project) { create(:kubernetes_project) }

        context 'and a deployment' do
          let!(:deployment) { create(:deployment, environment: environment) }
          it { is_expected.to be_truthy }
        end

        context 'but no deployments' do
          it { is_expected.to be_falsy }
        end
      end

      context 'without a deployment service' do
        it { is_expected.to be_falsy }
      end
    end

    context 'when the environment is unavailable' do
      let(:project) { create(:kubernetes_project) }

      before do
        environment.stop
      end

      it { is_expected.to be_falsy }
    end
  end

  describe '#terminals' do
    let(:project) { create(:kubernetes_project) }
    subject { environment.terminals }

    context 'when the environment has terminals' do
      before do
        allow(environment).to receive(:deployment_service_ready?).and_return(true)
      end

      it 'returns the terminals from the deployment service' do
        expect(project.deployment_service)
          .to receive(:terminals).with(environment)
          .and_return(:fake_terminals)

        is_expected.to eq(:fake_terminals)
      end
    end

    context 'when the environment does not have terminals' do
      before do
        allow(environment).to receive(:deployment_service_ready?).and_return(false)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#rollout_status' do
    let(:project) { create(:kubernetes_project) }
    subject { environment.rollout_status }

    context 'when the environment has rollout status' do
      before do
        allow(environment).to receive(:deployment_service_ready?).and_return(true)
      end

      it 'returns the rollout status from the deployment service' do
        expect(project.deployment_service).
          to receive(:rollout_status).with(environment).
          and_return(:fake_rollout_status)

        is_expected.to eq(:fake_rollout_status)
      end
    end

    context 'when the environment does not have rollout status' do
      before do
        allow(environment).to receive(:deployment_service_ready?).and_return(false)
      end

      it { is_expected.to eq(nil) }
    end
  end

  describe '#has_metrics?' do
    subject { environment.has_metrics? }

    context 'when the enviroment is available' do
      context 'with a deployment service' do
        let(:project) { create(:prometheus_project) }

        context 'and a deployment' do
          let!(:deployment) { create(:deployment, environment: environment) }
          it { is_expected.to be_truthy }
        end

        context 'but no deployments' do
          it { is_expected.to be_falsy }
        end
      end

      context 'without a monitoring service' do
        it { is_expected.to be_falsy }
      end
    end

    context 'when the environment is unavailable' do
      let(:project) { create(:prometheus_project) }

      before do
        environment.stop
      end

      it { is_expected.to be_falsy }
    end
  end

  describe '#metrics' do
    let(:project) { create(:prometheus_project) }
    subject { environment.metrics }

    context 'when the environment has metrics' do
      before do
        allow(environment).to receive(:has_metrics?).and_return(true)
      end

      it 'returns the metrics from the deployment service' do
        expect(project.monitoring_service)
          .to receive(:environment_metrics).with(environment)
          .and_return(:fake_metrics)

        is_expected.to eq(:fake_metrics)
      end
    end

    context 'when the environment does not have metrics' do
      before do
        allow(environment).to receive(:has_metrics?).and_return(false)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#has_metrics?' do
    subject { environment.has_metrics? }

    context 'when the enviroment is available' do
      context 'with a deployment service' do
        let(:project) { create(:prometheus_project) }

        context 'and a deployment' do
          let!(:deployment) { create(:deployment, environment: environment) }
          it { is_expected.to be_truthy }
        end

        context 'but no deployments' do
          it { is_expected.to be_falsy }
        end
      end

      context 'without a monitoring service' do
        it { is_expected.to be_falsy }
      end
    end

    context 'when the environment is unavailable' do
      let(:project) { create(:prometheus_project) }

      before do
        environment.stop
      end

      it { is_expected.to be_falsy }
    end
  end

  describe '#metrics' do
    let(:project) { create(:prometheus_project) }
    subject { environment.metrics }

    context 'when the environment has metrics' do
      before do
        allow(environment).to receive(:has_metrics?).and_return(true)
      end

      it 'returns the metrics from the deployment service' do
        expect(project.monitoring_service)
          .to receive(:environment_metrics).with(environment)
          .and_return(:fake_metrics)

        is_expected.to eq(:fake_metrics)
      end
    end

    context 'when the environment does not have metrics' do
      before do
        allow(environment).to receive(:has_metrics?).and_return(false)
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#slug' do
    it "is automatically generated" do
      expect(environment.slug).not_to be_nil
    end

    it "is not regenerated if name changes" do
      original_slug = environment.slug
      environment.update_attributes!(name: environment.name.reverse)

      expect(environment.slug).to eq(original_slug)
    end
  end

  describe '#generate_slug' do
    SUFFIX = "-[a-z0-9]{6}".freeze
    {
      "staging-12345678901234567" => "staging-123456789" + SUFFIX,
      "9-staging-123456789012345" => "env-9-staging-123" + SUFFIX,
      "staging-1234567890123456"  => "staging-1234567890123456",
      "production"                => "production",
      "PRODUCTION"                => "production" + SUFFIX,
      "review/1-foo"              => "review-1-foo" + SUFFIX,
      "1-foo"                     => "env-1-foo" + SUFFIX,
      "1/foo"                     => "env-1-foo" + SUFFIX,
      "foo-"                      => "foo" + SUFFIX,
      "foo--bar"                  => "foo-bar" + SUFFIX,
      "foo**bar"                  => "foo-bar" + SUFFIX,
      "*-foo"                     => "env-foo" + SUFFIX,
      "staging-12345678-"         => "staging-12345678" + SUFFIX,
      "staging-12345678-01234567" => "staging-12345678" + SUFFIX
    }.each do |name, matcher|
      it "returns a slug matching #{matcher}, given #{name}" do
        slug = described_class.new(name: name).generate_slug

        expect(slug).to match(/\A#{matcher}\z/)
      end
    end
  end

  describe '#external_url_for' do
    let(:source_path) { 'source/file.html' }
    let(:sha) { RepoHelpers.sample_commit.id }

    before do
      environment.external_url = 'http://example.com'
    end

    context 'when the public path is not known' do
      before do
        allow(project).to receive(:public_path_for_source_path).with(source_path, sha).and_return(nil)
      end

      it 'returns nil' do
        expect(environment.external_url_for(source_path, sha)).to be_nil
      end
    end

    context 'when the public path is known' do
      before do
        allow(project).to receive(:public_path_for_source_path).with(source_path, sha).and_return('file.html')
      end

      it 'returns the full external URL' do
        expect(environment.external_url_for(source_path, sha)).to eq('http://example.com/file.html')
      end
    end
  end
end
