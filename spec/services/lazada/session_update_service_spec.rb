# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lazada::SessionUpdateService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:session_id) { 'lazada-session-abc123' }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: session_id) }
  let(:timestamp_ms) { 1_700_000_000_000 }
  let(:expected_timestamp) { Time.zone.at(timestamp_ms / 1000.0).utc }

  let(:params) do
    {
      data: {
        session_id: session_id,
        to_position: timestamp_ms
      }
    }
  end

  describe '#perform' do
    context 'when a conversation exists for the session' do
      let!(:conversation) do
        create(
          :conversation,
          account: account,
          inbox: inbox,
          contact: contact,
          contact_inbox: contact_inbox,
          additional_attributes: { 'lazada_session_id' => session_id }
        )
      end

      it 'enqueues UpdateMessageStatusJob with conversation id and UTC timestamp' do
        expect(Conversations::UpdateMessageStatusJob).to receive(:perform_later).with(conversation.id, expected_timestamp)
        described_class.new(inbox: inbox, params: params).perform
      end

      it 'does not enqueue the job when to_position is blank' do
        expect(Conversations::UpdateMessageStatusJob).not_to receive(:perform_later)
        described_class.new(inbox: inbox, params: { data: { session_id: session_id } }).perform
      end
    end

    context 'when no conversation matches the session_id' do
      it 'does not enqueue any job' do
        expect(Conversations::UpdateMessageStatusJob).not_to receive(:perform_later)
        described_class.new(inbox: inbox, params: params).perform
      end
    end
  end
end
