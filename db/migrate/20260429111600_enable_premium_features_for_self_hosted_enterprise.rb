class EnablePremiumFeaturesForSelfHostedEnterprise < ActiveRecord::Migration[7.0]
  PREMIUM_FEATURES = %w[
    sla
    audit_logs
    custom_tools
    captain_integration
    captain_integration_v2
    custom_roles
    disable_branding
    help_center_embedding_search
    channel_voice
    advanced_search
  ].freeze

  def up
    # Skip on cloud installs - they manage feature defaults via Stripe plan limits.
    return if ChatwootApp.chatwoot_cloud?

    flip_account_level_feature_defaults
    backfill_existing_accounts
    GlobalConfig.clear_cache
  end

  def down
    # One-way data migration: reversing would require knowing which accounts had
    # which premium features enabled before the backfill. That state is not
    # preserved here, so reversal is unsafe.
    raise ActiveRecord::IrreversibleMigration
  end

  private

  # Flip the `enabled` bit for each premium feature in the
  # ACCOUNT_LEVEL_FEATURE_DEFAULTS InstallationConfig row so that newly-created
  # accounts inherit the enabled state via Featurable#enable_default_features.
  def flip_account_level_feature_defaults
    config = InstallationConfig.find_by(name: 'ACCOUNT_LEVEL_FEATURE_DEFAULTS')
    return if config.blank? || config.value.blank?

    features = config.value.map do |feature|
      if PREMIUM_FEATURES.include?(feature['name'])
        feature.merge('enabled' => true)
      else
        feature
      end
    end
    config.update!(value: features)
  end

  # Existing accounts already have feature_flags bits set when they were created,
  # so the YAML/InstallationConfig flip alone does not flip their bits. Walk every
  # account and turn on the premium feature flags.
  def backfill_existing_accounts
    Account.find_in_batches(batch_size: 100) do |accounts|
      accounts.each { |account| account.enable_features!(*PREMIUM_FEATURES) }
    end
  end
end
