# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lazada::RecallJob do
  let(:account) { create(:account) }
  let(:lazada_channel) { create(:channel_lazada, account: account) }
  let(:inbox) { lazada_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'buyer_123') }
  let(:conversation) do
    create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox, account: account)
  end
  let(:message) do
    create(:message, conversation: conversation, inbox: inbox, account: account,
                     message_type: :outgoing, source_id: 'lazada_msg_123')
  end

  describe '#perform' do
    it 'calls recall_im_message with the message source_id' do
      allow(Message).to receive(:find_by).with(id: message.id).and_return(message)
      allow(message.inbox).to receive(:channel).and_return(lazada_channel)
      expect(lazada_channel).to receive(:recall_im_message)
        .with(message_id: message.source_id)
        .and_return(OpenStruct.new(success?: true))

      described_class.new.perform(message.id)
    end

    it 'does nothing when message has no source_id' do
      message.update_column(:source_id, nil)
      allow(Message).to receive(:find_by).with(id: message.id).and_return(message)
      allow(message.inbox).to receive(:channel).and_return(lazada_channel)
      expect(lazada_channel).not_to receive(:recall_im_message)

      described_class.new.perform(message.id)
    end

    it 'does nothing when message is not found' do
      allow(Message).to receive(:find_by).with(id: 9999).and_return(nil)

      expect { described_class.new.perform(9999) }.not_to raise_error
    end

    it 'does nothing when inbox is not a Lazada channel' do
      non_lazada_channel = double('NotLazada')
      allow(Message).to receive(:find_by).with(id: message.id).and_return(message)
      allow(message.inbox).to receive(:channel).and_return(non_lazada_channel)
      expect(non_lazada_channel).not_to receive(:recall_im_message)

      described_class.new.perform(message.id)
    end

    it 'logs a warning when recall API returns failure' do
      allow(Message).to receive(:find_by).with(id: message.id).and_return(message)
      allow(message.inbox).to receive(:channel).and_return(lazada_channel)
      allow(lazada_channel).to receive(:recall_im_message)
        .with(message_id: message.source_id)
        .and_return(OpenStruct.new(success?: false, message: 'Some error'))

      expect(Rails.logger).to receive(:warn).with(/\[Lazada Recall\] Failed to recall message #{message.source_id}/)

      described_class.new.perform(message.id)
    end
  end
end
