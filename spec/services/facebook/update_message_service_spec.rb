# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Facebook::UpdateMessageService do
  let(:account) { create(:account) }
  let(:facebook_channel) { create(:channel_facebook_page, account: account) }
  let(:inbox) { facebook_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'FB_USER_PSID') }
  let(:conversation) do
    create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox, account: account)
  end
  let(:mid) { 'm_KXGKDUpO6xbVdAmZFBVpzU1AhKVJdAIUnUH4cwkvb' }

  before do
    # Required because Channel::FacebookPage's after_create_commit :subscribe callback
    # POSTs to Graph API. WebMock raises NetConnectNotAllowedError (not a StandardError),
    # so the rescue in `subscribe` does not catch it during tests.
    stub_request(:post, /graph.facebook.com/).to_return(status: 200, body: '', headers: {})
  end

  def build_response(identifier: mid, content: 'edited text')
    instance_double(Integrations::Facebook::MessageEditParser, identifier: identifier, content: content)
  end

  describe '#perform' do
    it 'updates message content when source_id matches and message is incoming' do
      message = create(:message, conversation: conversation, inbox: inbox, account: account,
                                 source_id: mid, content: 'original text')

      described_class.new(inbox: inbox, response: build_response).perform

      expect(message.reload.content).to eq('edited text')
    end

    it 'does nothing when no message is found with that source_id' do
      expect do
        described_class.new(inbox: inbox, response: build_response(identifier: 'unknown_mid')).perform
      end.not_to raise_error
    end

    it 'does nothing when response.identifier is blank' do
      message = create(:message, conversation: conversation, inbox: inbox, account: account,
                                 source_id: mid, content: 'original text')

      described_class.new(inbox: inbox, response: build_response(identifier: nil)).perform

      expect(message.reload.content).to eq('original text')
    end

    it 'does nothing when response.content is blank' do
      message = create(:message, conversation: conversation, inbox: inbox, account: account,
                                 source_id: mid, content: 'original text')

      described_class.new(inbox: inbox, response: build_response(content: nil)).perform

      expect(message.reload.content).to eq('original text')
    end

    it 'does nothing when the matched message is outgoing' do
      outgoing_msg = create(:message, conversation: conversation, inbox: inbox, account: account,
                                      message_type: :outgoing, source_id: mid, content: 'agent sent')

      described_class.new(inbox: inbox, response: build_response).perform

      expect(outgoing_msg.reload.content).to eq('agent sent')
    end
  end
end
