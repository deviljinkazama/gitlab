require 'spec_helper'

describe Gitlab::Mirror do
  include Gitlab::CurrentSettings

  before do
    Sidekiq::Logging.logger = nil
  end

  describe '#configure_cron_job!' do
    let(:cron) { Gitlab::Mirror::SCHEDULER_CRON }

    describe 'with jobs already running' do
      it 'creates a new cron job' do
        described_class.configure_cron_job!

        expect(subject).to receive(:destroy_cron_job!)
        expect(Sidekiq::Cron::Job).to receive(:create)

        expect { subject.configure_cron_job! }.to change { Sidekiq::Cron::Job.find("update_all_mirrors_worker") }
      end
    end

    describe 'without jobs already running' do
      before do
        Sidekiq::Cron::Job.find("update_all_mirrors_worker")&.destroy
      end

      it 'creates update_all_mirrors_worker' do
        expect { described_class.configure_cron_job! }.to change { Sidekiq::Cron::Job.find("update_all_mirrors_worker") }.from(nil).to(Sidekiq::Cron::Job)
        expect(Sidekiq::Cron::Job.find("update_all_mirrors_worker").cron).to eq(cron)
      end

      describe 'when Geo is enabled' do
        it 'disables mirror cron job' do
          described_class.configure_cron_job!

          expect(Sidekiq::Cron::Job.find("update_all_mirrors_worker")).to be_enabled

          allow(Gitlab::Geo).to receive(:secondary?).and_return(true)
          described_class.configure_cron_job!

          expect(Sidekiq::Cron::Job.find("update_all_mirrors_worker")).to be_nil
        end
      end
    end
  end

  describe '#max_mirror_capacity_reached?' do
    it 'returns true if available capacity is 0' do
      expect(described_class).to receive(:available_capacity).and_return(0)

      expect(described_class.max_mirror_capacity_reached?).to eq(true)
    end

    it 'returns false if available capacity is not 0' do
      expect(described_class).to receive(:available_capacity).and_return(1)

      expect(described_class.max_mirror_capacity_reached?).to eq(false)
    end

    after do
      Gitlab::Redis.with { |redis| redis.del(Gitlab::Mirror::PULL_CAPACITY_KEY) }
    end
  end

  describe '#threshold_reached?' do
    let(:mirror_capacity_threshold) { current_application_settings.mirror_capacity_threshold }

    it 'returns true if available capacity surpassed defined threshold' do
      expect(described_class).to receive(:available_capacity).and_return(mirror_capacity_threshold + 1)

      expect(described_class.threshold_reached?).to eq(true)
    end

    it 'returns true if available capacity is equal to the defined threshold' do
      expect(described_class).to receive(:available_capacity).and_return(mirror_capacity_threshold)

      expect(described_class.threshold_reached?).to eq(true)
    end

    it 'returns false if available capacity is below the defined threshold' do
      expect(described_class).to receive(:available_capacity).and_return(mirror_capacity_threshold - 1)

      expect(described_class.threshold_reached?).to eq(false)
    end

    after do
      Gitlab::Redis.with { |redis| redis.del(Gitlab::Mirror::PULL_CAPACITY_KEY) }
    end
  end

  describe '#available_capacity' do
    context 'when redis key does not exist' do
      it 'returns mirror_max_capacity' do
        expect(described_class.available_capacity).to eq(current_application_settings.mirror_max_capacity)
      end
    end

    context 'when redis key exists' do
      it 'returns available capacity' do
        current_capacity = 10

        Gitlab::Redis.with do |redis|
          (1..10).to_a.each do |id|
            redis.sadd(Gitlab::Mirror::PULL_CAPACITY_KEY, id)
          end
        end

        expect(described_class.available_capacity).to eq(current_application_settings.mirror_max_capacity - current_capacity)
      end
    end

    after do
      Gitlab::Redis.with { |redis| redis.del(Gitlab::Mirror::PULL_CAPACITY_KEY) }
    end
  end

  describe '#increment_capacity' do
    it 'increments capacity' do
      max_capacity = current_application_settings.mirror_max_capacity

      expect { described_class.increment_capacity(1) }.to change { described_class.available_capacity }.from(max_capacity).to(max_capacity - 1)
    end

    after do
      Gitlab::Redis.with { |redis| redis.del(Gitlab::Mirror::PULL_CAPACITY_KEY) }
    end
  end

  describe '#decrement_capacity' do
    let!(:id) { 1 }

    context 'with capacity above 0' do
      it 'decrements capacity' do
        max_capacity = current_application_settings.mirror_max_capacity

        described_class.increment_capacity(id)

        expect { described_class.decrement_capacity(id) }.to change { described_class.available_capacity }.from(max_capacity - 1).to(max_capacity)
      end
    end

    context 'with non-existent id' do
      it 'does not decrement capacity' do
        expect { described_class.decrement_capacity(id) }.not_to change { described_class.available_capacity }
      end
    end

    after do
      Gitlab::Redis.with { |redis| redis.del(Gitlab::Mirror::PULL_CAPACITY_KEY) }
    end
  end

  describe '#max_delay' do
    it 'returns max delay with some jitter' do
      expect(described_class.max_delay).to be_within(1.minute).of(5.hours)
    end
  end
end
