require 'rails_helper'

RSpec.describe ChatwootApp do
  describe '.self_hosted_enterprise?' do
    # `self_hosted_enterprise?` previously required
    # `GlobalConfig.get_value('INSTALLATION_PRICING_PLAN') == 'enterprise'`. That
    # made every enterprise feature gate trip off if the daily hub-sync job
    # overwrote the locally-managed plan value back to 'community'. The check
    # now relies only on the build edition + cloud flag.
    it 'is true when the enterprise edition is detected and not running on Chatwoot cloud' do
      allow(described_class).to receive(:enterprise?).and_return(true)
      allow(described_class).to receive(:chatwoot_cloud?).and_return(false)

      expect(described_class.self_hosted_enterprise?).to be true
    end

    it 'is false when running on Chatwoot cloud' do
      allow(described_class).to receive(:enterprise?).and_return(true)
      allow(described_class).to receive(:chatwoot_cloud?).and_return(true)

      expect(described_class.self_hosted_enterprise?).to be false
    end

    it 'is false on community installs (no enterprise/ folder)' do
      allow(described_class).to receive(:enterprise?).and_return(false)
      allow(described_class).to receive(:chatwoot_cloud?).and_return(false)

      expect(described_class.self_hosted_enterprise?).to be false
    end
  end
end
