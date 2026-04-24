# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::ReadStatusService do
  let(:account) { create(:account) }
  let(:line_channel) { create(:channel_line, account: account) }
  let(:inbox) { line_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'U123456') }
  let(:conversation) { create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox, account: account) }
  let(:timestamp_ms) { 1_700_000_000_000 }
  let(:expected_timestamp) { Time.zone.at(timestamp_ms / 1000.0).utc }

  let(:read_event) do
    {
      'type' => 'read',
      'timestamp' => timestamp_ms,
      'source' => { 'type' => 'user', 'userId' => 'U123456' }
    }
  end

  describe '#perform' do
    context 'when a conversation exists for the user' do
      before { conversation }

      it 'enqueues UpdateMessageStatusJob with conversation id and read timestamp' do
        expect(Conversations::UpdateMessageStatusJob).to receive(:perform_later).with(conversation.id, expected_timestamp)
        described_class.new(inbox: inbox, event: read_event).perform
      end
    end

    context 'when no conversation exists for the user' do
      it 'does not enqueue any job' do
        expect(Conversations::UpdateMessageStatusJob).not_to receive(:perform_later)
        described_class.new(inbox: inbox, event: read_event).perform
      end
    end
  end
end
