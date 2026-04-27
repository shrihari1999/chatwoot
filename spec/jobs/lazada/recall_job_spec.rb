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
    it 'delegates to OutgoingRecallService for the looked-up message' do
      service_double = instance_double(Lazada::OutgoingRecallService, perform: nil)
      expect(Lazada::OutgoingRecallService).to receive(:new).with(message: message).and_return(service_double)

      described_class.new.perform(message.id)
    end

    it 'does nothing when the message is not found' do
      missing_id = (Message.maximum(:id) || 0) + 1
      expect(Lazada::OutgoingRecallService).not_to receive(:new)

      expect { described_class.new.perform(missing_id) }.not_to raise_error
    end
  end
end
