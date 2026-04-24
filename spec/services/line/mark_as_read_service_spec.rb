# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::MarkAsReadService do
  let(:account) { create(:account) }
  let(:line_channel) { create(:channel_line, account: account) }
  let(:inbox) { line_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'U123456') }
  let(:conversation) { create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox, account: account) }

  let(:mock_client) { instance_double(Line::Bot::Client) }

  before do
    allow(line_channel).to receive(:client).and_return(mock_client)
    allow(mock_client).to receive(:endpoint).and_return('https://api.line.me/v2')
    allow(mock_client).to receive(:credentials).and_return({ 'Authorization' => 'Bearer test_token' })
    allow(mock_client).to receive(:post)
    allow(conversation.inbox).to receive(:channel).and_return(line_channel)
  end

  describe '#perform' do
    context 'when conversation has an incoming message with a mark_as_read_token' do
      before do
        create(:message, conversation: conversation, inbox: inbox, account: account,
                         message_type: :incoming,
                         additional_attributes: { mark_as_read_token: 'tok_abc123' })
      end

      it 'calls the LINE markAsRead API with the token' do
        expected_payload = { markAsReadToken: 'tok_abc123' }.to_json
        expect(mock_client).to receive(:post).with(
          'https://api.line.me/v2',
          '/bot/chat/markAsRead',
          expected_payload,
          { 'Authorization' => 'Bearer test_token' }
        )
        described_class.new(conversation: conversation).perform
      end
    end

    context 'when no incoming message has a mark_as_read_token' do
      before do
        create(:message, conversation: conversation, inbox: inbox, account: account,
                         message_type: :incoming,
                         additional_attributes: {})
      end

      it 'does not call the LINE API' do
        expect(mock_client).not_to receive(:post)
        described_class.new(conversation: conversation).perform
      end
    end

    context 'when the conversation is not a LINE inbox' do
      let(:other_inbox) { create(:inbox, account: account) }
      let(:other_conversation) { create(:conversation, inbox: other_inbox, account: account) }

      it 'does not call the LINE API' do
        expect(mock_client).not_to receive(:post)
        described_class.new(conversation: other_conversation).perform
      end
    end
  end
end
