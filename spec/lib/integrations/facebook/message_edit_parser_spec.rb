# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Integrations::Facebook::MessageEditParser do
  # The gem's Common#to_json wraps the raw messaging hash under a 'messaging' key,
  # so the job receives {"messaging": {"sender":..., "message_edit":...}}.
  let(:wrapped_payload) do
    {
      'messaging' => {
        'sender' => { 'id' => 'PSID_123' },
        'recipient' => { 'id' => 'PAGE_456' },
        'timestamp' => 1_458_668_856_463,
        'message_edit' => {
          'mid' => 'm_abc123',
          'text' => 'edited text here'
        }
      }
    }.to_json
  end

  # Also support the unwrapped shape (direct messaging hash) for robustness.
  let(:unwrapped_payload) do
    {
      'sender' => { 'id' => 'PSID_123' },
      'recipient' => { 'id' => 'PAGE_456' },
      'message_edit' => {
        'mid' => 'm_abc123',
        'text' => 'edited text here'
      }
    }.to_json
  end

  shared_examples 'parses fields correctly' do
    it 'extracts sender_id' do
      expect(parser.sender_id).to eq('PSID_123')
    end

    it 'extracts recipient_id' do
      expect(parser.recipient_id).to eq('PAGE_456')
    end

    it 'extracts identifier (mid)' do
      expect(parser.identifier).to eq('m_abc123')
    end

    it 'extracts content (text)' do
      expect(parser.content).to eq('edited text here')
    end
  end

  context 'with wrapped payload (gem Bot.on serialization shape)' do
    subject(:parser) { described_class.new(wrapped_payload) }

    it_behaves_like 'parses fields correctly'
  end

  context 'with unwrapped payload' do
    subject(:parser) { described_class.new(unwrapped_payload) }

    it_behaves_like 'parses fields correctly'
  end
end
