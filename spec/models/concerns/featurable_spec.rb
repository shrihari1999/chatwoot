# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Featurable do
  let(:account) { create(:account) }

  # Production-captured bitmask: channel_tiktok, channel_tiktok_shop,
  # csat_review_notes, captain_tasks ON; advanced_assignment (index 64) OFF.
  let(:prod_feature_flags) { 4_328_052_404_474_347_431 }

  describe 'bitmask column partition' do
    it 'splits features across feature_flags (indices 1..63) and feature_flags_extended (64+)' do
      expect(Account.flag_mapping['feature_flags'].size).to eq(63)
      expect(Account.flag_mapping['feature_flags_extended']).to eq(feature_advanced_assignment: 1)
    end

    it 'enables the 64th feature (advanced_assignment) without RangeError and routes it to the extended column' do
      expect { account.enable_features!('advanced_assignment') }.not_to raise_error

      account.reload
      expect(account.feature_advanced_assignment?).to be(true)
      expect(account.feature_flags_extended).to eq(1)
      expect(account.feature_flags).to eq(0) # primary column untouched by an extended flag
    end

    it 'keeps the index-63 feature in the primary column' do
      account.enable_features!('conversation_required_attributes')

      account.reload
      expect(account.feature_conversation_required_attributes?).to be(true)
      expect(account.feature_flags_extended).to eq(0)
    end
  end

  describe 'backward compatibility with a pre-existing single-column bitmask' do
    before { account.update!(feature_flags: prod_feature_flags, feature_flags_extended: 0) }

    it 'reads the preserved flags correctly (no data migration needed)' do
      account.reload
      expect(account.feature_channel_tiktok?).to be(true)
      expect(account.feature_channel_tiktok_shop?).to be(true)
      expect(account.feature_csat_review_notes?).to be(true)
      expect(account.feature_captain_tasks?).to be(true)
      expect(account.feature_conversation_required_attributes?).to be(false)
      expect(account.feature_advanced_assignment?).to be(false)
    end

    it 'leaves the primary column byte-for-byte intact when an extended flag is toggled' do
      account.reload
      account.enable_features!('advanced_assignment')

      account.reload
      expect(account.feature_flags).to eq(prod_feature_flags)
      expect(account.feature_flags_extended).to eq(1)
    end
  end

  describe 'account creation when the default feature set includes the 64th feature' do
    before do
      config = InstallationConfig.find_or_initialize_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
      config.value = [{ 'name' => 'advanced_assignment', 'enabled' => true }]
      config.save!
    end

    it 'creates the account without RangeError (the original overflow symptom)' do
      expect { create(:account) }.not_to raise_error
    end
  end
end
