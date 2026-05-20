require 'rails_helper'

RSpec.describe Team do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to have_many(:conversations) }
    it { is_expected.to have_many(:team_members) }
  end

  describe 'name casing' do
    let(:account) { create(:account) }

    it 'preserves the casing of the supplied name' do
      team = described_class.create!(account: account, name: 'Sales Team')
      expect(team.reload.name).to eq('Sales Team')
    end

    it 'rejects a case-variant duplicate within the same account' do
      described_class.create!(account: account, name: 'Sales Team')
      duplicate = described_class.new(account: account, name: 'sales team')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to be_present
    end

    it 'allows the same name in a different account' do
      described_class.create!(account: account, name: 'Sales Team')
      other_account = create(:account)
      expect(described_class.new(account: other_account, name: 'Sales Team')).to be_valid
    end
  end

  describe '#add_members' do
    let(:team) { FactoryBot.create(:team) }

    before do
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    it 'handles adds all members and resets cache keys' do
      users = FactoryBot.create_list(:user, 3)
      team.add_members(users.map(&:id))
      expect(team.reload.team_members.size).to eq(3)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).at_least(:once)
                                                                        .with(
                                                                          'account.cache_invalidated',
                                                                          kind_of(Time),
                                                                          account: team.account,
                                                                          cache_keys: team.account.cache_keys
                                                                        )
    end
  end

  describe '#remove_members' do
    let(:team) { FactoryBot.create(:team) }
    let(:users) { FactoryBot.create_list(:user, 3) }

    before do
      team.add_members(users.map(&:id))
      allow(Rails.configuration.dispatcher).to receive(:dispatch)
    end

    it 'removes the members and resets cache keys' do
      expect(team.reload.team_members.size).to eq(3)

      team.remove_members(users.map(&:id))
      expect(team.reload.team_members.size).to eq(0)

      expect(Rails.configuration.dispatcher).to have_received(:dispatch).at_least(:once)
                                                                        .with(
                                                                          'account.cache_invalidated',
                                                                          kind_of(Time),
                                                                          account: team.account,
                                                                          cache_keys: team.account.cache_keys
                                                                        )
    end
  end

  describe 'destroying a team' do
    it 'resets canned response categories scoped to it back to everyone' do
      account = create(:account)
      team = create(:team, account: account)
      category = create(:canned_response_category, account: account, visibility: :specific_team, team: team)

      team.destroy!

      category.reload
      expect(category.team_id).to be_nil
      expect(category.visibility).to eq('everyone')
    end
  end
end
