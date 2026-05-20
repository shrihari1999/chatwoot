# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CannedResponseCategory, type: :model do
  let(:account) { create(:account) }

  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to belong_to(:team).optional }
    it { is_expected.to have_many(:canned_responses).with_foreign_key(:category_id) }
  end

  describe 'validations' do
    subject { build(:canned_response_category, account: account) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:account_id) }

    it 'requires a user when visibility is only_me' do
      category = build(:canned_response_category, account: account, visibility: :only_me, user: nil)
      expect(category).not_to be_valid
      expect(category.errors[:user_id]).to be_present
    end

    it 'requires a team when visibility is specific_team' do
      category = build(:canned_response_category, account: account, visibility: :specific_team, team: nil)
      expect(category).not_to be_valid
      expect(category.errors[:team_id]).to be_present
    end
  end

  describe 'visibility' do
    it 'defaults to everyone' do
      expect(create(:canned_response_category, account: account).visibility).to eq('everyone')
    end

    it 'clears the team reference when not scoped to a team' do
      team = create(:team, account: account)
      category = create(:canned_response_category, account: account, visibility: :specific_team, team: team)
      category.update!(visibility: :everyone)
      expect(category.reload.team_id).to be_nil
    end

    it 'clears the user reference when not scoped to only_me' do
      user = create(:user, account: account)
      category = create(:canned_response_category, account: account, visibility: :only_me, user: user)
      category.update!(visibility: :everyone)
      expect(category.reload.user_id).to be_nil
    end
  end

  describe '.visible_to' do
    let(:user) { create(:user, account: account) }
    let(:team) { create(:team, account: account) }
    let(:other_team) { create(:team, account: account) }
    let(:other_user) { create(:user, account: account) }

    let!(:everyone_category) { create(:canned_response_category, account: account, visibility: :everyone) }
    let!(:own_category) { create(:canned_response_category, account: account, visibility: :only_me, user: user) }
    let!(:other_user_category) { create(:canned_response_category, account: account, visibility: :only_me, user: other_user) }
    let!(:team_category) { create(:canned_response_category, account: account, visibility: :specific_team, team: team) }
    let!(:other_team_category) { create(:canned_response_category, account: account, visibility: :specific_team, team: other_team) }

    before { create(:team_member, user: user, team: team) }

    it 'includes everyone, own only_me, and member-team categories' do
      visible = described_class.visible_to(user)
      expect(visible).to include(everyone_category, own_category, team_category)
      expect(visible).not_to include(other_user_category, other_team_category)
    end
  end
end
