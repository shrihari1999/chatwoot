# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lazada::RecallMessageService do
  let(:account) { create(:account) }
  let(:lazada_channel) { create(:channel_lazada, account: account) }
  let(:inbox) { lazada_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'buyer_123') }
  let(:conversation) do
    create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox, account: account)
  end
  let(:source_id) { 'lazada_msg_42' }

  def build_params(status:, message_id: source_id)
    { data: { status: status, message_id: message_id } }
  end

  describe '#perform' do
    it 'marks the message as deleted when status is 1 and source_id matches' do
      message = create(:message, conversation: conversation, inbox: inbox, account: account,
                                 source_id: source_id, content: 'original content')

      described_class.new(inbox: inbox, params: build_params(status: 1)).perform

      message.reload
      expect(message.content).to eq(I18n.t('conversations.messages.deleted'))
      expect(message.content_attributes[:deleted]).to be_truthy
    end

    it 'does nothing when status is 0' do
      message = create(:message, conversation: conversation, inbox: inbox, account: account,
                                 source_id: source_id, content: 'original content')

      described_class.new(inbox: inbox, params: build_params(status: 0)).perform

      message.reload
      expect(message.content).to eq('original content')
      expect(message.content_attributes[:deleted]).to be_falsey
    end

    it 'does nothing when the message is not found' do
      expect do
        described_class.new(inbox: inbox, params: build_params(status: 1, message_id: 'unknown_id')).perform
      end.not_to raise_error
    end

    it 'destroys attachments on the recalled message' do
      message = create(:message, :with_attachment, conversation: conversation, inbox: inbox, account: account,
                                                   source_id: source_id, content: 'original content')
      expect(message.attachments.count).to eq(1)

      described_class.new(inbox: inbox, params: build_params(status: 1)).perform

      expect(message.reload.attachments.count).to eq(0)
    end
  end
end
