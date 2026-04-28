# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::Facebook::MessageEditParser do
  let(:payload) do
    {
      'sender' => { 'id' => 'PSID_123' },
      'recipient' => { 'id' => 'PAGE_456' },
      'timestamp' => 1_458_668_856_463,
      'message_edit' => {
        'mid' => 'm_abc123',
        'text' => 'edited text here',
        'num_edit' => 2
      }
    }.to_json
  end

  subject(:parser) { described_class.new(payload) }

  describe '#sender_id' do
    it { expect(parser.sender_id).to eq('PSID_123') }
  end

  describe '#recipient_id' do
    it { expect(parser.recipient_id).to eq('PAGE_456') }
  end

  describe '#identifier' do
    it { expect(parser.identifier).to eq('m_abc123') }
  end

  describe '#content' do
    it { expect(parser.content).to eq('edited text here') }
  end
end
