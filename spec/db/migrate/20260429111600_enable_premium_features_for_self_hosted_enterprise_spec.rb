require 'rails_helper'
require Rails.root.join('db/migrate/20260429111600_enable_premium_features_for_self_hosted_enterprise.rb')

RSpec.describe EnablePremiumFeaturesForSelfHostedEnterprise do
  let(:migration) { described_class.new }
  let(:premium_features) { described_class::PREMIUM_FEATURES }

  describe '#up' do
    context 'when running on Chatwoot cloud' do
      before do
        allow(ChatwootApp).to receive(:chatwoot_cloud?).and_return(true)
      end

      it 'short-circuits without flipping defaults or touching accounts' do
        config = create(:installation_config, name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS', value: [
                          { 'name' => 'sla', 'enabled' => false, 'premium' => true }
                        ])
        account = create(:account)

        migration.up

        expect(config.reload.value.find { |f| f['name'] == 'sla' }['enabled']).to be(false)
        expect(account.reload.feature_enabled?(:sla)).to be(false)
      end
    end

    context 'when running on a self-hosted enterprise install' do
      before do
        allow(ChatwootApp).to receive(:chatwoot_cloud?).and_return(false)
      end

      it 'flips ACCOUNT_LEVEL_FEATURE_DEFAULTS for every premium feature' do
        seed_value = premium_features.map { |name| { 'name' => name, 'enabled' => false, 'premium' => true } } +
                     [{ 'name' => 'unrelated_feature', 'enabled' => false }]
        config = InstallationConfig.where(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
                                   .first_or_initialize
        config.update!(value: seed_value)

        migration.up

        flipped = config.reload.value
        premium_features.each do |feature|
          expect(flipped.find { |f| f['name'] == feature }['enabled']).to be(true), "expected #{feature} to be enabled"
        end
        expect(flipped.find { |f| f['name'] == 'unrelated_feature' }['enabled']).to be(false)
      end

      it 'turns on premium feature_flags bits for every existing account' do
        account = create(:account)
        # Sanity: at least one premium feature starts disabled before the migration.
        expect(account.feature_enabled?(:custom_tools)).to be(false)

        migration.up

        premium_features.each do |feature|
          expect(account.reload.feature_enabled?(feature)).to be(true), "expected account to have #{feature} enabled"
        end
      end

      it 'is a no-op on the defaults row when no ACCOUNT_LEVEL_FEATURE_DEFAULTS row exists' do
        InstallationConfig.where(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS').destroy_all

        expect { migration.up }.not_to raise_error
      end
    end
  end

  describe '#down' do
    it 'raises IrreversibleMigration' do
      expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration)
    end
  end
end
