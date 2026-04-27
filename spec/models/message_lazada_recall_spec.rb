# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Message do
  before do
    # rubocop:disable RSpec/AnyInstance
    allow_any_instance_of(described_class).to receive(:reindex_for_search).and_return(true)
    # rubocop:enable RSpec/AnyInstance
  end

  describe '#trigger_lazada_recall' do
    let(:account) { create(:account) }
    let(:lazada_channel) { create(:channel_lazada, account: account) }
    let(:lazada_inbox) { lazada_channel.inbox }
    let(:contact) { create(:contact, account: account) }
    let(:contact_inbox) { create(:contact_inbox, inbox: lazada_inbox, contact: contact, source_id: 'buyer_x') }
    let(:conversation) do
      create(:conversation, inbox: lazada_inbox, contact: contact, contact_inbox: contact_inbox, account: account)
    end
    let(:lazada_message) do
      create(:message, conversation: conversation, inbox: lazada_inbox, account: account,
                       message_type: :outgoing, source_id: 'lazada_src_1')
    end

    it 'enqueues RecallJob when an outgoing Lazada message transitions to deleted' do
      expect do
        lazada_message.update!(content: I18n.t('conversations.messages.deleted'),
                               content_attributes: { deleted: true })
      end.to have_enqueued_job(Lazada::RecallJob).with(lazada_message.id)
    end

    it 'does not enqueue when content_attributes change but message is already deleted' do
      lazada_message.update!(content: I18n.t('conversations.messages.deleted'),
                             content_attributes: { deleted: true })

      expect do
        lazada_message.update!(content_attributes: { deleted: true, extra: 'flag' })
      end.not_to have_enqueued_job(Lazada::RecallJob)
    end

    it 'does not enqueue for incoming messages' do
      incoming = create(:message, conversation: conversation, inbox: lazada_inbox, account: account,
                                  message_type: :incoming, source_id: 'lazada_src_2')

      expect do
        incoming.update!(content: I18n.t('conversations.messages.deleted'),
                         content_attributes: { deleted: true })
      end.not_to have_enqueued_job(Lazada::RecallJob)
    end

    it 'does not enqueue for non-Lazada channels' do
      api_channel = create(:channel_api, account: account)
      api_inbox = api_channel.inbox
      api_conversation = create(:conversation, inbox: api_inbox, account: account)
      api_message = create(:message, conversation: api_conversation, inbox: api_inbox, account: account,
                                     message_type: :outgoing, source_id: 'api_src_1')

      expect do
        api_message.update!(content: I18n.t('conversations.messages.deleted'),
                            content_attributes: { deleted: true })
      end.not_to have_enqueued_job(Lazada::RecallJob)
    end
  end
end
