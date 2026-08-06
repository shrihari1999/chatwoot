# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Lazada::IncomingMessageService do
  let(:account) { create(:account) }
  let(:lazada_channel) { create(:channel_lazada, account: account) }
  let(:inbox) { lazada_channel.inbox }

  describe '#perform' do
    it 'returns when data is blank' do
      expect(Lazada::IncomingRecallService).not_to receive(:new)
      described_class.new(inbox: inbox, params: { data: nil }).perform
    end

    it 'dispatches to IncomingRecallService when status=1, regardless of sender' do
      params = { data: { status: 1, message_id: 'm1', from_account_type: 1 } }
      service_double = instance_double(Lazada::IncomingRecallService, perform: nil)
      expect(Lazada::IncomingRecallService).to receive(:new).with(inbox: inbox, params: params).and_return(service_double)

      described_class.new(inbox: inbox, params: params).perform
    end

    it 'dispatches recalls from sellers to IncomingRecallService too' do
      # from_account_type=2 (seller) was previously short-circuited before the
      # recall check. This test locks in the new behaviour.
      params = { data: { status: 1, message_id: 'm2', from_account_type: 2 } }
      service_double = instance_double(Lazada::IncomingRecallService, perform: nil)
      expect(Lazada::IncomingRecallService).to receive(:new).with(inbox: inbox, params: params).and_return(service_double)

      described_class.new(inbox: inbox, params: params).perform
    end

    it 'skips a non-recall seller message when there is no existing conversation to echo into' do
      params = { data: { status: 0, message_id: 'm3', from_account_type: 2, session_id: 'sess-x', template_id: 1, content: { txt: 'hi' }.to_json } }
      expect(Lazada::IncomingRecallService).not_to receive(:new)

      described_class.new(inbox: inbox, params: params).perform

      expect(inbox.conversations.last).to be_nil
    end

    it 'treats string "1" status as a recall (Lazada sometimes sends status as a string)' do
      params = { data: { status: '1', message_id: 'm4', from_account_type: 1 } }
      service_double = instance_double(Lazada::IncomingRecallService, perform: nil)
      expect(Lazada::IncomingRecallService).to receive(:new).with(inbox: inbox, params: params).and_return(service_double)

      described_class.new(inbox: inbox, params: params).perform
    end

    it 'does not treat status=2 as a recall' do
      params = { data: { status: 2, message_id: 'm5', from_account_type: 2 } }
      # from_account_type=2 (seller) ensures we short-circuit after the recall
      # check without needing to stub the full message creation path.
      expect(Lazada::IncomingRecallService).not_to receive(:new)

      described_class.new(inbox: inbox, params: params).perform
    end
  end

  describe 'outbound echo (seller message sent from the Lazada seller app)' do
    # Establish a conversation the way it happens in production: the buyer messages
    # first, then the seller replies (which arrives as an echo on the webhook).
    def buyer_opens_conversation
      data = { template_id: 1, from_account_type: 1, from_user_id: 'u1', message_id: 'buyer-1',
               session_id: 'sess-1', content: { txt: 'is this in stock?' }.to_json }
      described_class.new(inbox: inbox, params: { data: data }).perform
    end

    def echo(message_id: 'echo-1', text: 'yes, it is!')
      data = { template_id: 1, from_account_type: 2, from_user_id: 'seller-1', message_id: message_id,
               session_id: 'sess-1', content: { txt: text }.to_json }
      described_class.new(inbox: inbox, params: { data: data }).perform
    end

    it 'mirrors a seller message into the thread as an outgoing echo' do
      buyer_opens_conversation
      echo

      msg = inbox.conversations.last.messages.last
      expect(msg.content).to eq('yes, it is!')
      expect(msg.message_type).to eq('outgoing')
      expect(msg.status).to eq('delivered')
      expect(msg.sender).to be_nil
      expect(msg.content_attributes['external_echo']).to be(true)
    end

    it 'skips an echo when the buyer has no existing conversation yet' do
      echo

      expect(inbox.conversations.last).to be_nil
    end

    it 'dedups an echo of a message we already have by source_id (our own Chatwoot sends)' do
      buyer_opens_conversation
      echo(message_id: 'dup-1')

      expect { echo(message_id: 'dup-1') }
        .not_to(change { inbox.conversations.last.messages.count })
    end

    it 'attaches the echo to the latest conversation when an older resolved one shares the session id' do
      buyer_opens_conversation
      old_conversation = inbox.conversations.last
      old_conversation.update!(status: :resolved)
      buyer_opens_conversation
      new_conversation = inbox.conversations.order(:created_at).last
      expect(new_conversation).not_to eq(old_conversation)

      echo

      expect(new_conversation.messages.last.content).to eq('yes, it is!')
      expect(old_conversation.messages.reload.none? { |m| m.content_attributes['external_echo'] }).to be(true)
    end
  end

  describe 'marketing push (template 200016)' do
    # A real "sem_seller_engagement_push" payload: Lazada's seller-ads broadcast,
    # HTML content, delivered on the same webhook as buyer chat.
    def marketing_push(status: 0, message_id: 'push-1')
      {
        data: {
          template_id: 200_016, from_account_type: 1, from_user_id: '100021725907',
          status: status, message_id: message_id, session_id: 'sess-push', site_id: 'TH',
          content: { txt: '<img width="250" src="https://img.lazcdn.com/us/sem_seller_engagement_push/x.png"></img>' }.to_json
        }
      }
    end

    it 'drops it without creating a conversation, contact or message' do
      described_class.new(inbox: inbox, params: marketing_push).perform

      expect(inbox.conversations).to be_empty
      expect(inbox.contact_inboxes).to be_empty
      expect(Message.where(inbox_id: inbox.id)).to be_empty
    end

    it 'does not enqueue an avatar fetch for it' do
      expect(Lazada::ContactProfileJob).not_to receive(:perform_later)

      described_class.new(inbox: inbox, params: marketing_push).perform
    end

    it 'drops a recall of a marketing push too — we never ingested the original' do
      expect(Lazada::IncomingRecallService).not_to receive(:new)

      described_class.new(inbox: inbox, params: marketing_push(status: 1)).perform
    end

    it 'still ingests an ordinary message from the same account' do
      data = { template_id: 1, from_account_type: 1, from_user_id: '100021725907', message_id: 'sys-1',
               session_id: 'sess-push', content: { txt: 'your order was updated' }.to_json }

      described_class.new(inbox: inbox, params: { data: data }).perform

      expect(inbox.conversations.last.messages.last.content).to eq('your order was updated')
    end
  end

  describe 'contact profile enrichment' do
    let(:params) do
      {
        data: {
          template_id: 1, from_account_type: 1, from_user_id: 'u1', message_id: 'm20',
          session_id: 'sess-1', content: { txt: 'hi' }.to_json
        }
      }
    end

    it 'enqueues an avatar fetch for an incoming buyer message with a session_id' do
      expect(Lazada::ContactProfileJob).to receive(:perform_later).with(
        channel_id: lazada_channel.id, contact_id: kind_of(Integer), session_id: 'sess-1'
      )

      described_class.new(inbox: inbox, params: params).perform
    end

    it 'does not enqueue when the session_id is missing' do
      params[:data].delete(:session_id)
      expect(Lazada::ContactProfileJob).not_to receive(:perform_later)

      described_class.new(inbox: inbox, params: params).perform
    end
  end

  describe 'image attachment' do
    let(:img_url) { 'https://lazada-cdn.local/sample.png' }
    let(:params) do
      {
        data: {
          template_id: 3, from_account_type: 1, from_user_id: 'u1', message_id: 'm10',
          content: { imgUrl: img_url }.to_json
        }
      }
    end

    it 'downloads the image bytes into storage instead of persisting the remote url' do
      stub_request(:get, img_url)
        .to_return(status: 200, body: 'imagedata', headers: { 'Content-Type' => 'image/png' })

      described_class.new(inbox: inbox, params: params).perform

      attachment = inbox.conversations.last.messages.last.attachments.last
      expect(attachment.file_type).to eq('image')
      expect(attachment.file.attached?).to be(true)
      expect(attachment.external_url).to be_nil
    end

    it 'falls back to external_url when the download fails' do
      stub_request(:get, img_url).to_raise(Down::Error.new('boom'))

      described_class.new(inbox: inbox, params: params).perform

      attachment = inbox.conversations.last.messages.last.attachments.last
      expect(attachment.file_type).to eq('image')
      expect(attachment.external_url).to eq(img_url)
    end
  end
end
