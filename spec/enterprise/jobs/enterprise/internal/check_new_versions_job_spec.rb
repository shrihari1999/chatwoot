require 'rails_helper'

RSpec.describe Internal::CheckNewVersionsJob do
  subject(:job) { described_class.perform_now }

  let(:reconsile_premium_config_service) { instance_double(Internal::ReconcilePlanConfigService) }

  before do
    allow(Internal::ReconcilePlanConfigService).to receive(:new).and_return(reconsile_premium_config_service)
    allow(reconsile_premium_config_service).to receive(:perform)
    allow(Rails.env).to receive(:production?).and_return(true)
  end

  it 'updates the plan info' do
    data = { 'version' => '1.2.3', 'plan' => 'enterprise', 'plan_quantity' => 1, 'chatwoot_support_website_token' => '123',
             'chatwoot_support_identifier_hash' => '123', 'chatwoot_support_script_url' => '123' }
    allow(ChatwootHub).to receive(:sync_with_hub).and_return(data)
    job
    expect(InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN').value).to eq 'enterprise'
    expect(InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').value).to eq 1
    expect(InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_WEBSITE_TOKEN').value).to eq '123'
    expect(InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_IDENTIFIER_HASH').value).to eq '123'
    expect(InstallationConfig.find_by(name: 'CHATWOOT_SUPPORT_SCRIPT_URL').value).to eq '123'
  end

  it 'calls Internal::ReconcilePlanConfigService' do
    data = { 'version' => '1.2.3' }
    allow(ChatwootHub).to receive(:sync_with_hub).and_return(data)
    job
    expect(reconsile_premium_config_service).to have_received(:perform)
  end

  # FORK: with the real (stubbed) ChatwootHub, the job must not touch the plan.
  it 'leaves the pricing plan unchanged when the hub sync is stubbed' do
    allow(RestClient).to receive(:post)
    InstallationConfig.where(name: 'INSTALLATION_PRICING_PLAN').first_or_create!(value: 'enterprise').update!(value: 'enterprise', locked: true)
    InstallationConfig.where(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').first_or_create!(value: 9_999_999).update!(value: 9_999_999)
    expect { job }.not_to raise_error
    expect(RestClient).not_to have_received(:post)
    expect(InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN').value).to eq 'enterprise'
    expect(InstallationConfig.find_by(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').value).to eq 9_999_999
  end

  # FORK: the stub must accept the refresh_billing keyword the job passes (v4.20).
  it 'runs with refresh_billing against the stubbed hub' do
    allow(RestClient).to receive(:post)
    expect(described_class.perform_now(refresh_billing: true)).to be(false)
    expect(RestClient).not_to have_received(:post)
  end

  it 'reports whether hub was reached' do
    allow(ChatwootHub).to receive(:sync_with_hub).and_return({ 'version' => '1.2.3' })
    expect(described_class.perform_now).to be(true)

    allow(ChatwootHub).to receive(:sync_with_hub).and_return(nil)
    expect(described_class.perform_now).to be(false)
  end

  context 'when hub reports the installation subscription status' do
    let!(:accounts) { create_list(:account, 2) }

    before do
      InstallationConfig.create!(name: 'INSTALLATION_SUBSCRIPTION_STATUS', value: 'active', locked: true)
    end

    it 'stores the new status and notifies every account with its own account id' do
      allow(ChatwootHub).to receive(:sync_with_hub).and_return({ 'version' => '1.2.3', 'subscription_status' => 'past_due' })
      first, second = accounts

      expect { job }
        .to have_broadcasted_to("account_#{first.id}").with(event: 'account.billing_updated', data: { account_id: first.id })
        .and have_broadcasted_to("account_#{second.id}").with(event: 'account.billing_updated', data: { account_id: second.id })
      expect(ChatwootHub.subscription_status).to eq 'past_due'
    end

    it 'does not notify accounts when the status is unchanged' do
      allow(ChatwootHub).to receive(:sync_with_hub).and_return({ 'version' => '1.2.3', 'subscription_status' => 'active' })

      expect { job }.not_to have_broadcasted_to("account_#{accounts.first.id}")
    end

    it 'keeps the last known status when an older hub omits it' do
      allow(ChatwootHub).to receive(:sync_with_hub).and_return({ 'version' => '1.2.3' })

      job

      expect(ChatwootHub.subscription_status).to eq 'active'
    end

    it 'clears the status when hub returns null' do
      allow(ChatwootHub).to receive(:sync_with_hub).and_return({ 'version' => '1.2.3', 'subscription_status' => nil })

      job

      expect(ChatwootHub.subscription_status).to be_nil
    end
  end
end
