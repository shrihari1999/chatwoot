# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facebook::MarkAsReadService do
  let(:account) { create(:account) }
  let(:facebook_channel) { create(:channel_facebook_page, account: account) }
  let(:inbox) { facebook_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'buyer_psid_123') }
  let(:conversation) do
    create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox, account: account)
  end

  before do
    allow(conversation.inbox).to receive(:channel).and_return(facebook_channel)
    allow(contact).to receive(:get_source_id).with(inbox.id).and_return('buyer_psid_123')
  end

  describe '#perform' do
    context 'when conversation is a Facebook inbox' do
      it 'calls Facebook::Messenger::Bot.deliver with mark_seen sender_action' do
        expect(Facebook::Messenger::Bot).to receive(:deliver).with(
          { recipient: { id: 'buyer_psid_123' }, sender_action: 'mark_seen' },
          page_id: facebook_channel.page_id
        )
        described_class.new(conversation: conversation).perform
      end
    end

    context 'when recipient PSID is blank' do
      before do
        allow(contact).to receive(:get_source_id).with(inbox.id).and_return(nil)
      end

      it 'does not call the Facebook API' do
        expect(Facebook::Messenger::Bot).not_to receive(:deliver)
        described_class.new(conversation: conversation).perform
      end
    end

    context 'when the conversation is not a Facebook inbox' do
      let(:other_inbox) { create(:inbox, account: account) }
      let(:other_conversation) { create(:conversation, inbox: other_inbox, account: account) }

      it 'does not call the Facebook API' do
        expect(Facebook::Messenger::Bot).not_to receive(:deliver)
        described_class.new(conversation: other_conversation).perform
      end
    end

    context 'when Facebook API raises a FacebookError' do
      it 'logs a warning and does not raise' do
        allow(Facebook::Messenger::Bot).to receive(:deliver).and_raise(Facebook::Messenger::FacebookError, 'auth error')
        expect(Rails.logger).to receive(:warn).with(/Failed to send mark_seen/)
        expect { described_class.new(conversation: conversation).perform }.not_to raise_error
      end
    end

    context 'when an unexpected error occurs' do
      it 'logs a warning and does not raise' do
        allow(Facebook::Messenger::Bot).to receive(:deliver).and_raise(StandardError, 'network error')
        expect(Rails.logger).to receive(:warn).with(/Unexpected error/)
        expect { described_class.new(conversation: conversation).perform }.not_to raise_error
      end
    end
  end
end
