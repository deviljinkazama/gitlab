require 'spec_helper'

describe UsersFinder do
  describe '#execute' do
    let!(:user1) { create(:user, username: 'johndoe') }
    let!(:user2) { create(:user, :blocked, username: 'notsorandom') }
    let!(:external_user) { create(:user, :external) }
    let!(:omniauth_user) { create(:omniauth_user, provider: 'twitter', extern_uid: '123456') }

    context 'with a normal user' do
      let(:user) { create(:user) }

      it 'returns all users' do
        users = described_class.new(user).execute

        expect(users).to contain_exactly(user, user1, user2, omniauth_user)
      end

      it 'filters by username' do
        users = described_class.new(user, username: 'johndoe').execute

        expect(users).to contain_exactly(user1)
      end

      it 'filters by search' do
        users = described_class.new(user, search: 'orando').execute

        expect(users).to contain_exactly(user2)
      end

      it 'filters by blocked users' do
        users = described_class.new(user, blocked: true).execute

        expect(users).to contain_exactly(user2)
      end

      it 'filters by active users' do
        users = described_class.new(user, active: true).execute

        expect(users).to contain_exactly(user, user1, omniauth_user)
      end

      it 'returns no external users' do
        users = described_class.new(user, external: true).execute

        expect(users).to contain_exactly(user, user1, user2, omniauth_user)
      end

      context 'with LDAP users' do
        let!(:ldap_user) { create(:omniauth_user, provider: 'ldap') }

        it 'returns ldap users by default' do
          users = described_class.new(user).execute

          expect(users).to contain_exactly(user, user1, user2, omniauth_user, ldap_user)
        end

        it 'returns only non-ldap users with skip_ldap: true' do
          users = described_class.new(user, skip_ldap: true).execute

          expect(users).to contain_exactly(user, user1, user2, omniauth_user)
        end
      end
    end

    context 'with an admin user' do
      let(:admin) { create(:admin) }

      it 'filters by external users' do
        users = described_class.new(admin, external: true).execute

        expect(users).to contain_exactly(external_user)
      end

      it 'returns all users' do
        users = described_class.new(admin).execute

        expect(users).to contain_exactly(admin, user1, user2, external_user, omniauth_user)
      end
    end
  end
end
