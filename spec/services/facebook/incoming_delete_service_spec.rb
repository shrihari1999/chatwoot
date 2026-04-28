# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facebook::IncomingDeleteService do
  before do
    allow(Facebook::Messenger::Subscriptions).to receive(:subscribe).and_return(true)
  end

  let(:account) { create(:account) }
  let(:facebook_channel) { create(:channel_facebook_page, account: account) }
  let(:inbox) { facebook_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'FB_USER_PSID') }
  let(:conversation) do
    create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox, account: account)
  end
  let(:mid) { 'm_KXGKDUpO6xbVdAmZFBVpzU1AhKVJdAIUnUH4cwkvb' }

  def build_response(identifier: mid)
    instance_double(Integrations::Facebook::MessageParser, identifier: identifier)
  end

  describe '#perform' do
    it 'marks the message as deleted when source_id matches the mid' do
      message = create(:message, conversation: conversation, inbox: inbox, account: account,
                                 source_id: mid, content: 'original content')

      described_class.new(inbox: inbox, response: build_response).perform

      expect(message.reload).to have_attributes(
        content: I18n.t('conversations.messages.deleted'),
        deleted: true
      )
    end

    it 'does nothing when no message is found with that source_id' do
      expect do
        described_class.new(inbox: inbox, response: build_response(identifier: 'unknown_mid')).perform
      end.not_to raise_error
    end

    it 'destroys attachments on the deleted message' do
      message = create(:message, :with_attachment, conversation: conversation, inbox: inbox, account: account,
                                                   source_id: mid, content: 'original content')
      expect(message.attachments.count).to eq(1)

      described_class.new(inbox: inbox, response: build_response).perform

      expect(message.reload.attachments.count).to eq(0)
    end

    it 'does nothing when the matched message is outgoing' do
      outgoing_msg = create(:message, conversation: conversation, inbox: inbox, account: account,
                                      message_type: :outgoing, source_id: mid, content: 'agent sent')

      described_class.new(inbox: inbox, response: build_response).perform

      expect(outgoing_msg.reload.content).to eq('agent sent')
    end

    it 'does nothing when response.identifier returns nil' do
      message = create(:message, conversation: conversation, inbox: inbox, account: account,
                                 source_id: mid, content: 'original content')

      expect do
        described_class.new(inbox: inbox, response: build_response(identifier: nil)).perform
      end.not_to raise_error

      expect(message.reload.content).to eq('original content')
    end
  end
end
