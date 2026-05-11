# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Instagram::CommentService do
  let!(:account) { create(:account) }
  let!(:channel) { create(:channel_instagram, account: account, instagram_id: 'BUSINESS_IGSID') }
  let!(:inbox)   { channel.inbox }

  let(:value) do
    {
      'id' => '18094947671518722',
      'from' => { 'id' => 'COMMENTER_IGSID', 'username' => 'shrihari.12' },
      'media' => { 'id' => '17841443698384602', 'media_product_type' => 'FEED' },
      'text' => 'Test comment'
    }.with_indifferent_access
  end

  describe '#perform' do
    it 'creates an incoming message with comment metadata when a new commenter comments' do
      described_class.new(value: value, channel: channel, ig_account_id: 'BUSINESS_IGSID').perform

      contact = inbox.contacts.last
      conversation = contact.conversations.last
      message = conversation.messages.last

      expect(contact.name).to eq 'shrihari.12'
      expect(contact.contact_inboxes.find_by(source_id: 'COMMENTER_IGSID')).to be_present

      expect(message.incoming?).to be true
      expect(message.content).to eq 'Test comment'
      expect(message.source_id).to eq '18094947671518722'
      expect(message.content_attributes['source_type']).to eq 'instagram_comment'
      expect(message.content_attributes['comment_id']).to eq '18094947671518722'
      expect(message.content_attributes['post_id']).to eq '17841443698384602'
      expect(message.content_attributes).not_to have_key('parent_comment_id')

      expect(conversation.additional_attributes['type']).to eq 'instagram_post_comment'
    end

    it 'reuses the existing conversation when the commenter already has one (per-contact UX)' do
      existing_contact_inbox = channel.create_contact_inbox('COMMENTER_IGSID', 'shrihari.12')
      contact = existing_contact_inbox.contact
      existing_conversation = create(:conversation, account: account, inbox: inbox, contact: contact,
                                                    contact_inbox: existing_contact_inbox)

      described_class.new(value: value, channel: channel, ig_account_id: 'BUSINESS_IGSID').perform

      expect(contact.reload.conversations.count).to eq 1
      expect(existing_conversation.reload.messages.last.content).to eq 'Test comment'
    end

    it 'records parent_comment_id when the comment is itself a reply to another comment' do
      value['parent_id'] = 'PARENT_COMMENT_ID'

      described_class.new(value: value, channel: channel, ig_account_id: 'BUSINESS_IGSID').perform

      expect(inbox.messages.last.content_attributes['parent_comment_id']).to eq 'PARENT_COMMENT_ID'
    end

    it 'is a no-op when the commenter is the business itself (own-comment echo)' do
      value['from']['id'] = 'BUSINESS_IGSID'

      expect do
        described_class.new(value: value, channel: channel, ig_account_id: 'BUSINESS_IGSID').perform
      end.not_to change { inbox.messages.count }
    end

    it 'is a no-op when comment text is missing' do
      value['text'] = nil

      expect do
        described_class.new(value: value, channel: channel, ig_account_id: 'BUSINESS_IGSID').perform
      end.not_to change { inbox.messages.count }
    end

    it 'is idempotent against duplicate webhook deliveries (same comment_id)' do
      svc = -> { described_class.new(value: value, channel: channel, ig_account_id: 'BUSINESS_IGSID').perform }
      svc.call
      expect { svc.call }.not_to change { inbox.messages.count }
    end
  end
end
