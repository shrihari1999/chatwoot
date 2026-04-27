# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lazada::OutgoingRecallService do
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
    it 'calls recall_im_message with the message source_id on the channel' do
      success_response = double('Response', success?: true) # rubocop:disable RSpec/VerifiedDoubles
      allow(message.inbox).to receive(:channel).and_return(lazada_channel)
      expect(lazada_channel).to receive(:recall_im_message)
        .with(message_id: message.source_id)
        .and_return(success_response)

      described_class.new(message: message).perform
    end

    it 'does nothing when message has no source_id' do
      message.update!(source_id: nil)
      allow(message.inbox).to receive(:channel).and_return(lazada_channel)
      expect(lazada_channel).not_to receive(:recall_im_message)

      described_class.new(message: message).perform
    end

    it 'does nothing when inbox is not a Lazada channel' do
      api_channel = create(:channel_api, account: account)
      api_inbox = api_channel.inbox
      api_conversation = create(:conversation, inbox: api_inbox, account: account)
      api_message = create(:message, conversation: api_conversation, inbox: api_inbox, account: account,
                                     message_type: :outgoing, source_id: 'src_id_1')

      # No channel stubbing — Channel::Api does not respond to recall_im_message and
      # the service must short-circuit before invoking the channel.
      expect { described_class.new(message: api_message).perform }.not_to raise_error
    end

    it 'logs a warning when recall API returns failure' do
      failure_response = double('Response', success?: false, message: 'Some error') # rubocop:disable RSpec/VerifiedDoubles
      allow(message.inbox).to receive(:channel).and_return(lazada_channel)
      allow(lazada_channel).to receive(:recall_im_message)
        .with(message_id: message.source_id)
        .and_return(failure_response)

      expect(Rails.logger).to receive(:warn).with(/\[Lazada Recall\] Failed to recall message #{message.source_id}/)

      described_class.new(message: message).perform
    end
  end
end
