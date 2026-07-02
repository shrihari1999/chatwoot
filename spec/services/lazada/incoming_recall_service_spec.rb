# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lazada::IncomingRecallService do
  let(:account) { create(:account) }
  let(:lazada_channel) { create(:channel_lazada, account: account) }
  let(:inbox) { lazada_channel.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, inbox: inbox, contact: contact, source_id: 'buyer_123') }
  let(:conversation) do
    create(:conversation, inbox: inbox, contact: contact, contact_inbox: contact_inbox, account: account)
  end
  let(:source_id) { 'lazada_msg_42' }

  def build_params(message_id: source_id)
    { data: { message_id: message_id } }
  end

  describe '#perform' do
    it 'marks the message as deleted when source_id matches' do
      message = create(:message, conversation: conversation, inbox: inbox, account: account,
                                 source_id: source_id, content: 'original content')

      described_class.new(inbox: inbox, params: build_params).perform

      message.reload
      expect(message.content).to eq(I18n.t('conversations.messages.deleted'))
      expect(message.content_attributes[:deleted]).to be_truthy
    end

    it 'does nothing when the message is not found' do
      expect do
        described_class.new(inbox: inbox, params: build_params(message_id: 'unknown_id')).perform
      end.not_to raise_error
    end

    it 'destroys attachments on the recalled message' do
      message = create(:message, :with_attachment, conversation: conversation, inbox: inbox, account: account,
                                                   source_id: source_id, content: 'original content')
      expect(message.attachments.count).to eq(1)

      described_class.new(inbox: inbox, params: build_params).perform

      expect(message.reload.attachments.count).to eq(0)
    end

    it 'marks an outgoing message deleted without enqueuing a recall (platform-originated, no API loop)' do
      outgoing_msg = create(:message, conversation: conversation, inbox: inbox, account: account,
                                      message_type: :outgoing, source_id: source_id, content: 'agent sent')

      expect do
        described_class.new(inbox: inbox, params: build_params).perform
      end.not_to have_enqueued_job(Lazada::RecallJob)

      outgoing_msg.reload
      expect(outgoing_msg.content).to eq(I18n.t('conversations.messages.deleted'))
      expect(outgoing_msg.content_attributes[:deleted]).to be_truthy
    end

    it 'reflects a recall of an outgoing external_echo message without enqueuing a recall' do
      echo_msg = create(:message, conversation: conversation, inbox: inbox, account: account,
                                  message_type: :outgoing, source_id: source_id, content: 'seller echo',
                                  content_attributes: { external_echo: true })

      expect do
        described_class.new(inbox: inbox, params: build_params).perform
      end.not_to have_enqueued_job(Lazada::RecallJob)

      expect(echo_msg.reload.content).to eq(I18n.t('conversations.messages.deleted'))
    end

    it 'does nothing when params data is blank' do
      message = create(:message, conversation: conversation, inbox: inbox, account: account,
                                 source_id: source_id, content: 'original content')

      expect do
        described_class.new(inbox: inbox, params: { data: nil }).perform
      end.not_to raise_error

      expect(message.reload.content).to eq('original content')
    end

    it 'does nothing when data is present but message_id is blank' do
      message = create(:message, conversation: conversation, inbox: inbox, account: account,
                                 source_id: source_id, content: 'original content')

      expect do
        described_class.new(inbox: inbox, params: { data: { message_id: nil } }).perform
      end.not_to raise_error

      expect(message.reload.content).to eq('original content')
    end

    it 'rolls back attachment deletion when update! fails (transactional)' do
      message = create(:message, :with_attachment, conversation: conversation, inbox: inbox, account: account,
                                                   source_id: source_id, content: 'original content')

      # rubocop:disable RSpec/AnyInstance
      # Force the update! to fail and verify attachments are NOT destroyed
      # (i.e. the transaction is rolled back).
      allow_any_instance_of(Message).to receive(:update!).and_raise(ActiveRecord::RecordInvalid)
      # rubocop:enable RSpec/AnyInstance

      expect do
        described_class.new(inbox: inbox, params: build_params).perform
      end.to raise_error(ActiveRecord::RecordInvalid)

      expect(message.reload.attachments.count).to eq(1)
    end
  end
end
