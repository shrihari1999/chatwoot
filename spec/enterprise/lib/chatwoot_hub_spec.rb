require 'rails_helper'

RSpec.describe ChatwootHub do
  describe '.base_url' do
    it 'uses the static hub url outside development for enterprise edition' do
      with_modified_env CHATWOOT_HUB_URL: 'https://custom.example.com' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))

        expect(described_class.base_url).to eq('https://hub.2.chatwoot.com')
      end
    end

    it 'uses CHATWOOT_HUB_URL in development for enterprise edition' do
      with_modified_env CHATWOOT_HUB_URL: 'https://custom.example.com' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))

        expect(described_class.base_url).to eq('https://custom.example.com')
      end
    end
  end

  # InstallationConfig#value is JSON-serialized, and the live production value for
  # INSTALLATION_PRICING_PLAN_QUANTITY is stored as a String (e.g. "9999999"). The
  # /super_admin/settings page does `User.count > ChatwootHub.pricing_plan_quantity`,
  # which raised an ArgumentError ("comparison of Integer with String failed") and
  # returned a 500. Casting to integer fixes the comparison.
  describe '.pricing_plan_quantity' do
    before { allow(ChatwootApp).to receive(:enterprise?).and_return(true) }

    it 'returns 0 for non-enterprise installs' do
      allow(ChatwootApp).to receive(:enterprise?).and_return(false)
      expect(described_class.pricing_plan_quantity).to eq(0)
    end

    it 'returns 0 when the installation config is missing' do
      allow(InstallationConfig).to receive(:find_by).with(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').and_return(nil)
      expect(described_class.pricing_plan_quantity).to eq(0)
    end

    # Regression test for the 500 on /super_admin/settings: prod stores the value as a String.
    it 'casts a string-valued config to integer so it can be compared against User.count' do
      config = instance_double(InstallationConfig, value: '5')
      allow(InstallationConfig).to receive(:find_by).with(name: 'INSTALLATION_PRICING_PLAN_QUANTITY').and_return(config)

      result = described_class.pricing_plan_quantity

      expect(result).to eq(5)
      expect(result).to be_a(Integer)
    end
  end
end
