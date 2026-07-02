# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tiktok::TypingStatusService do
  let(:account) { create(:account) }
  let(:tiktok_channel) { create(:channel_tiktok, account: account, business_id: 'biz-123') }
  let(:inbox) { tiktok_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'tt-conv-1') }
  let(:conversation) do
    create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox, account: account,
                          additional_attributes: { 'conversation_id' => 'tt-conv-1' })
  end
  let(:tiktok_client) { instance_double(Tiktok::Client, send_typing_action: nil) }

  before do
    allow(Tiktok::TokenService).to receive(:new).and_return(instance_double(Tiktok::TokenService, access_token: 'fresh-token'))
    allow(Tiktok::Client).to receive(:new).and_return(tiktok_client)
  end

  describe '#perform' do
    context 'when typing_status is on and the conversation has a TikTok conversation_id' do
      it 'calls Tiktok::Client#send_typing_action with the conversation_id' do
        described_class.new(conversation: conversation, typing_status: 'on').perform

        expect(Tiktok::Client).to have_received(:new).with(business_id: 'biz-123', access_token: 'fresh-token')
        expect(tiktok_client).to have_received(:send_typing_action).with('tt-conv-1')
      end
    end

    context 'when typing_status is off' do
      it 'does not call the TikTok API (TikTok has no stop for the typing action)' do
        described_class.new(conversation: conversation, typing_status: 'off').perform

        expect(Tiktok::Client).not_to have_received(:new)
      end
    end

    context 'when conversation has no TikTok conversation_id in additional_attributes' do
      let(:conversation) do
        create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                              account: account, additional_attributes: {})
      end

      it 'does not call the TikTok API' do
        described_class.new(conversation: conversation, typing_status: 'on').perform

        expect(Tiktok::Client).not_to have_received(:new)
      end
    end

    context 'when the conversation is not a TikTok inbox' do
      let(:other_inbox) { create(:inbox, account: account) }
      let(:other_conversation) { create(:conversation, inbox: other_inbox, account: account) }

      it 'does not call the TikTok API' do
        described_class.new(conversation: other_conversation, typing_status: 'on').perform

        expect(Tiktok::Client).not_to have_received(:new)
      end
    end

    context 'when the TikTok client raises' do
      before do
        allow(tiktok_client).to receive(:send_typing_action).and_raise(StandardError, 'boom')
      end

      it 'logs a warning that includes the conversation id and does not raise' do
        expect(Rails.logger).to receive(:warn).with(
          a_string_matching(/\[Tiktok TypingStatus\] Failed to send typing for conversation #{conversation.id}: boom/)
        )
        expect { described_class.new(conversation: conversation, typing_status: 'on').perform }.not_to raise_error
      end
    end
  end
end
