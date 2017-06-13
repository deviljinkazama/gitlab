require 'spec_helper'

describe Gitlab::Kubernetes::Deployment do
  subject(:deployment) { described_class.new(params) }

  describe '#name' do
    let(:params) { named(:selected) }

    it { expect(deployment.name).to eq(:selected) }
  end

  describe '#labels' do
    let(:params) { make('metadata', 'labels' => :selected) }

    it { expect(deployment.labels).to eq(:selected) }
  end

  describe '#outdated?' do
    context 'when outdated' do
      let(:params) { generation(2, 1) }

      it { expect(deployment.outdated?).to be_truthy }
    end

    context 'when up to date' do
      let(:params) { generation(2, 2) }

      it { expect(deployment.outdated?).to be_falsy }
    end

    context 'when ahead of latest' do
      let(:params) { generation(1, 2) }

      it { expect(deployment.outdated?).to be_falsy }
    end
  end

  describe '#wanted_replicas' do
    let(:params) { make('spec', 'replicas' => :selected ) }

    it { expect(deployment.wanted_replicas).to eq(:selected) }
  end

  describe '#finished_replicas' do
    let(:params) { make('status', 'availableReplicas' => :selected) }

    it { expect(deployment.finished_replicas).to eq(:selected) }
  end

  describe '#deploying_replicas' do
    let(:params) { make('status', 'availableReplicas' => 2, 'updatedReplicas' => 4) }

    it { expect(deployment.deploying_replicas).to eq(2) }
  end

  describe '#waiting_replicas' do
    let(:params) { combine(make('spec', 'replicas' => 4), make('status', 'updatedReplicas' => 2)) }

    it { expect(deployment.waiting_replicas).to eq(2) }
  end

  describe '#instances' do
    context 'when unnamed' do
      let(:params) { combine(generation(1, 1), instances) }

      it 'returns all instances as unknown and waiting' do
        expected = [
          { status: 'waiting', tooltip: 'unknown (pod 0) Waiting', track: 'stable', stable: true },
          { status: 'waiting', tooltip: 'unknown (pod 1) Waiting', track: 'stable', stable: true },
          { status: 'waiting', tooltip: 'unknown (pod 2) Waiting', track: 'stable', stable: true },
          { status: 'waiting', tooltip: 'unknown (pod 3) Waiting', track: 'stable', stable: true }
        ]

        expect(deployment.instances).to eq(expected)
      end
    end

    context 'when outdated' do
      let(:params) { combine(named('foo'), generation(1, 0), instances) }

      it 'returns all instances as named and waiting' do
        expected = [
          { status: 'waiting', tooltip: 'foo (pod 0) Waiting', track: 'stable', stable: true },
          { status: 'waiting', tooltip: 'foo (pod 1) Waiting', track: 'stable', stable: true },
          { status: 'waiting', tooltip: 'foo (pod 2) Waiting', track: 'stable', stable: true },
          { status: 'waiting', tooltip: 'foo (pod 3) Waiting', track: 'stable', stable: true }
        ]

        expect(deployment.instances).to eq(expected)
      end
    end

    context 'with pods of each type' do
      let(:params) { combine(named('foo'), generation(1, 1), instances) }

      it 'returns all instances' do
        expected = [
          { status: 'finished',  tooltip: 'foo (pod 0) Finished', track: 'stable', stable: true },
          { status: 'deploying', tooltip: 'foo (pod 1) Deploying', track: 'stable', stable: true },
          { status: 'waiting',   tooltip: 'foo (pod 2) Waiting', track: 'stable', stable: true },
          { status: 'waiting',   tooltip: 'foo (pod 3) Waiting', track: 'stable', stable: true }
        ]

        expect(deployment.instances).to eq(expected)
      end
    end

    context 'with track label' do
      let(:labels) { { 'track' => track } }
      let(:params) { combine(named('foo', labels), generation(1, 0), instances(1, 1, 1, labels)) }

      context 'when marked as stable' do
        let(:track) { 'stable' }

        it 'returns all instances' do
          expected = [
            { status: 'waiting',  tooltip: 'foo (pod 0) Waiting', track: 'stable', stable: true }
          ]

          expect(deployment.instances).to eq(expected)
        end
      end

      context 'when marked as canary' do
        let(:track) { 'canary' }

        it 'returns all instances' do
          expected = [
            { status: 'waiting',  tooltip: 'foo (pod 0) Waiting', track: 'canary', stable: false }
          ]

          expect(deployment.instances).to eq(expected)
        end
      end
    end
  end

  def generation(expected, observed)
    combine(
      make('metadata', 'generation' => expected),
      make('status', 'observedGeneration' => observed)
    )
  end

  def named(name = "foo", labels = {})
    make('metadata', 'name' => name, 'labels' => labels)
  end

  def instances(replicas = 4, available = 1, updated = 2, labels = {})
    combine(
      make('spec', 'replicas' => replicas),
      make('status', 'availableReplicas' => available, 'updatedReplicas' => updated)
    )
  end

  def make(key, values = {})
    hsh = {}
    hsh[key] = values
    hsh
  end

  def combine(*hashes)
    out = {}
    hashes.each { |hsh| out = out.deep_merge(hsh) }
    out
  end
end
