# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Instagram::UpdateMessageService do
  let(:account) { create(:account) }
  let(:instagram_channel) { create(:channel_instagram, account: account, instagram_id: 'chatwoot-app-user-id-1') }
  let(:inbox) { create(:inbox, channel: instagram_channel, account: account, greeting_enabled: false) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'IG_USER_ID') }
  let(:conversation) do
    create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox, account: account)
  end
  let(:mid) { 'm_KXGKDUpO6xbVdAmZFBVpzU1AhKVJdAIUnUH4cwkvb' }

  before do
    # Channel::Instagram#subscribe POSTs to the IG Graph API on create. Stub it out
    # so factories work without network access.
    stub_request(:post, /graph\.instagram\.com/).to_return(status: 200, body: '', headers: {})
  end

  def messaging_for(identifier: mid, content: 'edited text')
    {
      sender: { id: 'IG_USER_ID' },
      recipient: { id: 'chatwoot-app-user-id-1' },
      message_edit: { mid: identifier, text: content, num_edit: 1 }
    }.with_indifferent_access
  end

  describe '#perform' do
    it 'updates message content when source_id matches and message is incoming' do
      message = create(:message, conversation: conversation, inbox: inbox, account: account,
                                 source_id: mid, content: 'original text')

      described_class.new(inbox: inbox, messaging: messaging_for).perform

      message.reload
      expect(message.content).to eq('edited text')
      expect(message.edited).to be true
    end

    it 'does nothing when no message is found with that source_id' do
      expect do
        described_class.new(inbox: inbox, messaging: messaging_for(identifier: 'unknown_mid')).perform
      end.not_to raise_error
    end

    it 'does nothing when mid is blank' do
      message = create(:message, conversation: conversation, inbox: inbox, account: account,
                                 source_id: mid, content: 'original text')

      described_class.new(inbox: inbox, messaging: messaging_for(identifier: nil)).perform

      expect(message.reload.content).to eq('original text')
    end

    it 'does nothing when text is blank' do
      message = create(:message, conversation: conversation, inbox: inbox, account: account,
                                 source_id: mid, content: 'original text')

      described_class.new(inbox: inbox, messaging: messaging_for(content: nil)).perform

      expect(message.reload.content).to eq('original text')
    end

    it 'does nothing when the matched message is outgoing' do
      outgoing_msg = create(:message, conversation: conversation, inbox: inbox, account: account,
                                      message_type: :outgoing, source_id: mid, content: 'agent sent')

      described_class.new(inbox: inbox, messaging: messaging_for).perform

      expect(outgoing_msg.reload.content).to eq('agent sent')
    end
  end
end
