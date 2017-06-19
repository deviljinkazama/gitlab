require "spec_helper"

describe License do
  let(:gl_license)  { build(:gitlab_license) }
  let(:license)     { build(:license, data: gl_license.export) }

  describe "Validation" do
    describe "Valid license" do
      context "when the license is provided" do
        it "is valid" do
          expect(license).to be_valid
        end
      end

      context "when no license is provided" do
        before do
          license.data = nil
        end

        it "is invalid" do
          expect(license).not_to be_valid
        end
      end
    end

    describe "Historical active user count" do
      let(:active_user_count) { User.active.count + 10 }
      let(:date)              { described_class.current.starts_at }
      let!(:historical_data)  { HistoricalData.create!(date: date, active_user_count: active_user_count) }

      context "when there is no active user count restriction" do
        it "is valid" do
          expect(license).to be_valid
        end
      end

      context "when the active user count restriction is exceeded" do
        before do
          gl_license.restrictions = { active_user_count: active_user_count - 1 }
        end

        context "when the license started" do
          it "is invalid" do
            expect(license).not_to be_valid
          end
        end

        context "after the license started" do
          let(:date) { Date.today }

          it "is valid" do
            expect(license).to be_valid
          end
        end

        context "in the year before the license started" do
          let(:date) { described_class.current.starts_at - 6.months }

          it "is invalid" do
            expect(license).not_to be_valid
          end
        end

        context "earlier than a year before the license started" do
          let(:date) { described_class.current.starts_at - 2.years }

          it "is valid" do
            expect(license).to be_valid
          end
        end
      end

      context "when the active user count restriction is not exceeded" do
        before do
          gl_license.restrictions = { active_user_count: active_user_count + 1 }
        end

        it "is valid" do
          expect(license).to be_valid
        end
      end

      context "when the active user count is met exactly" do
        it "is valid" do
          active_user_count = 100
          gl_license.restrictions = { active_user_count: active_user_count }

          expect(license).to be_valid
        end
      end

      context 'with true-up info' do
        context 'when quantity is ok' do
          before do
            set_restrictions(restricted_user_count: 5, trueup_quantity: 10)
          end

          it 'is valid' do
            expect(license).to be_valid
          end

          context 'but active users exceeds restricted user count' do
            it 'is invalid' do
              6.times { create(:user) }

              expect(license).not_to be_valid
            end
          end
        end

        context 'when quantity is wrong' do
          it 'is invalid' do
            set_restrictions(restricted_user_count: 5, trueup_quantity: 8)

            expect(license).not_to be_valid
          end
        end

        context 'when previous user count is not present' do
          before do
            set_restrictions(restricted_user_count: 5, trueup_quantity: 7)
          end

          it 'uses current active user count to calculate the expected true-up' do
            3.times { create(:user) }

            expect(license).to be_valid
          end

          context 'with wrong true-up quantity' do
            it 'is invalid' do
              2.times { create(:user) }

              expect(license).not_to be_valid
            end
          end
        end

        context 'when previous user count is present' do
          before do
            set_restrictions(restricted_user_count: 5, trueup_quantity: 6, previous_user_count: 4)
          end

          it 'uses it to calculate the expected true-up' do
            expect(license).to be_valid
          end
        end
      end
    end

    describe "Not expired" do
      context "when the license doesn't expire" do
        it "is valid" do
          expect(license).to be_valid
        end
      end

      context "when the license has expired" do
        before do
          gl_license.expires_at = Date.yesterday
        end

        it "is invalid" do
          expect(license).not_to be_valid
        end
      end

      context "when the license has yet to expire" do
        before do
          gl_license.expires_at = Date.tomorrow
        end

        it "is valid" do
          expect(license).to be_valid
        end
      end
    end

    describe 'downgrade' do
      context 'when more users were added in previous period' do
        before do
          HistoricalData.create!(date: 6.months.ago, active_user_count: 15)

          set_restrictions(restricted_user_count: 5, previous_user_count: 10)
        end

        it 'is invalid without a true-up' do
          expect(license).not_to be_valid
        end
      end

      context 'when no users were added in the previous period' do
        before do
          HistoricalData.create!(date: 6.months.ago, active_user_count: 15)

          set_restrictions(restricted_user_count: 10, previous_user_count: 15)
        end

        it 'is valid' do
          expect(license).to be_valid
        end
      end
    end
  end

  describe "Class methods" do
    let!(:license) { described_class.last }

    before do
      described_class.reset_current
      allow(described_class).to receive(:last).and_return(license)
    end

    describe '.features_for_plan' do
      it 'returns features for starter plan' do
        expect(described_class.features_for_plan('starter'))
          .to include({ 'GitLab_MultipleIssueAssignees' => 1 })
      end

      it 'returns features for premium plan' do
        expect(described_class.features_for_plan('premium'))
          .to include({ 'GitLab_MultipleIssueAssignees' => 1, 'GitLab_DeployBoard' => 1, 'GitLab_FileLocks' => 1 })
      end

      it 'returns features for early adopter plan' do
        expect(described_class.features_for_plan('premium'))
          .to include({ 'GitLab_DeployBoard' => 1, 'GitLab_FileLocks' => 1 }, )
      end

      it 'returns empty Hash if no features for given plan' do
        expect(described_class.features_for_plan('bronze')).to eq({})
      end
    end

    describe '.plan_includes_feature?' do
      let(:feature) { :deploy_board }
      subject { described_class.plan_includes_feature?(plan, feature) }

      context 'when addon included' do
        let(:plan) { 'premium' }

        it 'returns true' do
          is_expected.to eq(true)
        end
      end

      context 'when addon not included' do
        let(:plan) { 'starter' }

        it 'returns false' do
          is_expected.to eq(false)
        end
      end

      context 'when plan is not set' do
        let(:plan) { nil }

        it 'returns false' do
          is_expected.to eq(false)
        end
      end

      context 'when feature does not exists' do
        let(:plan) { 'premium' }
        let(:feature) { nil }

        it 'raises KeyError' do
          expect { subject }.to raise_error(KeyError)
        end
      end
    end

    describe ".current" do
      context "when there is no license" do
        let!(:license) { nil }

        it "returns nil" do
          expect(described_class.current).to be_nil
        end
      end

      context "when the license is invalid" do
        before do
          allow(license).to receive(:valid?).and_return(false)
        end

        it "returns nil" do
          expect(described_class.current).to be_nil
        end
      end

      context "when the license is valid" do
        it "returns the license" do
          expect(described_class.current)
        end
      end
    end

    describe ".block_changes?" do
      context "when there is no current license" do
        before do
          allow(described_class).to receive(:current).and_return(nil)
        end

        it "returns true" do
          expect(described_class.block_changes?).to be_truthy
        end
      end

      context "when the current license is set to block changes" do
        before do
          allow(license).to receive(:block_changes?).and_return(true)
        end

        it "returns true" do
          expect(described_class.block_changes?).to be_truthy
        end
      end

      context "when the current license doesn't block changes" do
        it "returns false" do
          expect(described_class.block_changes?).to be_falsey
        end
      end
    end
  end

  describe "#license" do
    context "when no data is provided" do
      before do
        license.data = nil
      end

      it "returns nil" do
        expect(license.license).to be_nil
      end
    end

    context "when corrupt license data is provided" do
      before do
        license.data = "whatever"
      end

      it "returns nil" do
        expect(license.license).to be_nil
      end
    end

    context "when valid license data is provided" do
      it "returns the license" do
        expect(license.license).not_to be_nil
      end
    end
  end

  describe 'reading add-ons' do
    describe '#plan' do
      it 'interprets no plan as EES' do
        license = build(:license, data: build(:gitlab_license, restrictions: { add_ons: {} }).export)

        expect(license.plan).to eq(License::STARTER_PLAN)
      end

      it 'interprets an unknown plan as unknown' do
        license = build_license_with_add_ons({}, plan: 'unknown')

        expect(license.plan).to eq('unknown')
      end
    end

    describe '#add_ons' do
      context 'without add-ons' do
        it 'returns an empty Hash' do
          license = build_license_with_add_ons({})

          expect(license.add_ons).to eq({})
        end
      end

      context 'with add-ons' do
        it 'returns all available add-ons' do
          license = build_license_with_add_ons({ License::DEPLOY_BOARD_FEATURE => 1, License::FILE_LOCK_FEATURE => 2 })

          expect(license.add_ons.keys).to include(License::DEPLOY_BOARD_FEATURE, License::FILE_LOCK_FEATURE)
        end

        it 'can return details about a single add-on' do
          license = build_license_with_add_ons({ License::DEPLOY_BOARD_FEATURE => 2 })

          expect(license.add_ons[License::DEPLOY_BOARD_FEATURE]).to eq(2)
        end
      end

      context 'with extra features mapped by plan' do
        it 'returns all available add-ons and extra features' do
          license = build_license_with_add_ons({ License::DEPLOY_BOARD_FEATURE => 1 }, plan: License::PREMIUM_PLAN)
          eep_features = License::EEP_FEATURES.reduce({}, :merge).keys

          expect(license.add_ons.keys).to include(License::DEPLOY_BOARD_FEATURE, *eep_features)
        end
      end
    end

    describe '#feature_available?' do
      it 'returns true if add-on exists and have a quantity greater than 0' do
        license = build_license_with_add_ons({ License::DEPLOY_BOARD_FEATURE => 1 })

        expect(license.feature_available?(:deploy_board)).to eq(true)
      end

      it 'returns false if add-on exists but have a quantity of 0' do
        license = build_license_with_add_ons({ License::DEPLOY_BOARD_FEATURE => 0 })

        expect(license.feature_available?(:deploy_board)).to eq(false)
      end

      it 'returns false if add-on does not exists' do
        license = build_license_with_add_ons({})

        expect(license.feature_available?(:deploy_board)).to eq(false)
      end

      it 'raises error if invalid symbol is sent' do
        license = build_license_with_add_ons({})

        expect { license.feature_available?(:invalid) }.to raise_error(KeyError)
      end
    end

    def build_license_with_add_ons(add_ons, plan: nil)
      gl_license = build(:gitlab_license, restrictions: { add_ons: add_ons, plan: plan })
      build(:license, data: gl_license.export)
    end
  end

  def set_restrictions(opts)
    gl_license.restrictions = {
      active_user_count: opts[:restricted_user_count],
      previous_user_count: opts[:previous_user_count],
      trueup_quantity: opts[:trueup_quantity],
      trueup_from: (Date.today - 1.year).to_s,
      trueup_to: Date.today.to_s
    }
  end
end
