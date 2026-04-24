# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lazada::MarkAsReadService do
  let(:account) { create(:account) }
  let(:lazada_channel) { create(:channel_lazada, account: account) }
  let(:inbox) { lazada_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'buyer_123') }
  let(:conversation) do
    create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                          account: account,
                          additional_attributes: { 'lazada_session_id' => 'sess_abc' })
  end

  before do
    allow(conversation.inbox).to receive(:channel).and_return(lazada_channel)
    allow(lazada_channel).to receive(:read_session)
  end

  describe '#perform' do
    context 'when conversation has a lazada_session_id' do
      it 'calls read_session on the channel with the session id' do
        expect(lazada_channel).to receive(:read_session).with(session_id: 'sess_abc')
        described_class.new(conversation: conversation).perform
      end
    end

    context 'when conversation has no lazada_session_id' do
      let(:conversation) do
        create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox,
                              account: account, additional_attributes: {})
      end

      it 'does not call read_session' do
        expect(lazada_channel).not_to receive(:read_session)
        described_class.new(conversation: conversation).perform
      end
    end

    context 'when the conversation is not a Lazada inbox' do
      let(:other_inbox) { create(:inbox, account: account) }
      let(:other_conversation) { create(:conversation, inbox: other_inbox, account: account) }

      it 'does not call read_session' do
        expect(lazada_channel).not_to receive(:read_session)
        described_class.new(conversation: other_conversation).perform
      end
    end
  end
end
