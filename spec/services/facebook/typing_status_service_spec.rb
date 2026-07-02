# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facebook::TypingStatusService do
  before do
    allow(Facebook::Messenger::Subscriptions).to receive(:subscribe).and_return(true)
  end

  let(:account) { create(:account) }
  let(:facebook_channel) { create(:channel_facebook_page, account: account) }
  let(:inbox) { facebook_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'buyer_psid_123') }
  let(:conversation) do
    create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox, account: account)
  end

  describe '#perform' do
    context 'when conversation is a Facebook inbox' do
      it 'calls Facebook::Messenger::Bot.deliver with typing_on sender_action' do
        expect(Facebook::Messenger::Bot).to receive(:deliver).with(
          { recipient: { id: 'buyer_psid_123' }, sender_action: 'typing_on' },
          page_id: facebook_channel.page_id
        )
        described_class.new(conversation: conversation, typing_status: 'on').perform
      end

      it 'calls Facebook::Messenger::Bot.deliver with typing_off sender_action' do
        expect(Facebook::Messenger::Bot).to receive(:deliver).with(
          { recipient: { id: 'buyer_psid_123' }, sender_action: 'typing_off' },
          page_id: facebook_channel.page_id
        )
        described_class.new(conversation: conversation, typing_status: 'off').perform
      end
    end

    context 'when typing_status is unrecognised' do
      it 'does not call the Facebook API' do
        expect(Facebook::Messenger::Bot).not_to receive(:deliver)
        described_class.new(conversation: conversation, typing_status: 'maybe').perform
      end
    end

    context 'when conversation is an Instagram DM on a Facebook page channel' do
      before do
        conversation.update!(additional_attributes: { 'type' => 'instagram_direct_message' })
      end

      it 'does not call the Facebook API' do
        expect(Facebook::Messenger::Bot).not_to receive(:deliver)
        described_class.new(conversation: conversation, typing_status: 'on').perform
      end
    end

    context 'when recipient PSID is blank' do
      before do
        allow_any_instance_of(Contact).to receive(:get_source_id).with(inbox.id).and_return(nil)
      end

      it 'does not call the Facebook API' do
        expect(Facebook::Messenger::Bot).not_to receive(:deliver)
        described_class.new(conversation: conversation, typing_status: 'on').perform
      end
    end

    context 'when the conversation is not a Facebook inbox' do
      let(:other_inbox) { create(:inbox, account: account) }
      let(:other_conversation) { create(:conversation, inbox: other_inbox, account: account) }

      it 'does not call the Facebook API' do
        expect(Facebook::Messenger::Bot).not_to receive(:deliver)
        described_class.new(conversation: other_conversation, typing_status: 'on').perform
      end
    end

    context 'when Facebook API raises a FacebookError' do
      it 'logs a warning that includes the conversation id and does not raise' do
        fb_error = Facebook::Messenger::FacebookError.new('message' => 'auth error')
        allow(Facebook::Messenger::Bot).to receive(:deliver).and_raise(fb_error)
        expect(Rails.logger).to receive(:warn).with(
          a_string_matching(/\[Facebook TypingStatus\] Failed to send typing_on for conversation #{conversation.id}: .*auth error/)
        )
        expect { described_class.new(conversation: conversation, typing_status: 'on').perform }.not_to raise_error
      end
    end
  end
end
