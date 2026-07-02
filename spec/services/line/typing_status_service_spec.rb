# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Line::TypingStatusService do
  let(:account) { create(:account) }
  let(:line_channel) { create(:channel_line, account: account) }
  let(:inbox) { line_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'U123456') }
  let(:conversation) { create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox, account: account) }

  let(:mock_client) { instance_double(Line::Bot::Client) }
  let(:ok_response) { instance_double(Net::HTTPResponse, code: '200', body: '{}') }

  before do
    allow(line_channel).to receive(:client).and_return(mock_client)
    allow(mock_client).to receive(:endpoint).and_return('https://api.line.me/v2')
    allow(mock_client).to receive(:credentials).and_return({ 'Authorization' => 'Bearer test_token' })
    allow(mock_client).to receive(:post).and_return(ok_response)
    allow(conversation.inbox).to receive(:channel).and_return(line_channel)
  end

  describe '#perform' do
    context 'when typing_status is on' do
      it 'calls the LINE Loading Animation API with chatId and loadingSeconds' do
        expected_payload = { chatId: 'U123456', loadingSeconds: 20 }.to_json
        expect(mock_client).to receive(:post).with(
          'https://api.line.me/v2',
          '/bot/chat/loading/start',
          expected_payload,
          { 'Authorization' => 'Bearer test_token' }
        ).and_return(ok_response)
        described_class.new(conversation: conversation, typing_status: 'on').perform
      end
    end

    context 'when typing_status is off' do
      it 'does not call the LINE API (LINE has no stop for the animation)' do
        expect(mock_client).not_to receive(:post)
        described_class.new(conversation: conversation, typing_status: 'off').perform
      end
    end

    context 'when the contact_inbox source_id is blank' do
      it 'does not call the LINE API' do
        allow(conversation.contact_inbox).to receive(:source_id).and_return(nil)
        expect(mock_client).not_to receive(:post)
        described_class.new(conversation: conversation, typing_status: 'on').perform
      end
    end

    context 'when the conversation is not a LINE inbox' do
      let(:other_inbox) { create(:inbox, account: account) }
      let(:other_conversation) { create(:conversation, inbox: other_inbox, account: account) }

      it 'does not call the LINE API' do
        expect(mock_client).not_to receive(:post)
        described_class.new(conversation: other_conversation, typing_status: 'on').perform
      end
    end

    context 'when the LINE API responds with a non-200 status' do
      let(:error_response) { instance_double(Net::HTTPResponse, code: '400', body: '{"message":"invalid chatId"}') }

      it 'logs a warning and does not raise' do
        allow(mock_client).to receive(:post).and_return(error_response)
        expect(Rails.logger).to receive(:warn).with(
          a_string_matching(/\[Line TypingStatus\] Loading animation request failed for conversation #{conversation.id}: 400 .*invalid chatId/)
        )
        expect { described_class.new(conversation: conversation, typing_status: 'on').perform }.not_to raise_error
      end
    end

    context 'when the LINE client raises' do
      it 'logs a warning and does not raise' do
        allow(mock_client).to receive(:post).and_raise(StandardError.new('network down'))
        expect(Rails.logger).to receive(:warn).with(
          a_string_matching(/\[Line TypingStatus\] Failed to start loading animation for conversation #{conversation.id}: network down/)
        )
        expect { described_class.new(conversation: conversation, typing_status: 'on').perform }.not_to raise_error
      end
    end
  end
end
