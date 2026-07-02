# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Tiktok::Shop::IncomingMessageService do
  let(:account) { create(:account) }
  let(:channel) { create(:channel_tiktok_shop, account: account) }
  let(:inbox) { channel.inbox }

  def perform(data)
    described_class.new(channel: channel, payload: { data: data }).perform
  end

  def last_message
    inbox.conversations.last&.messages&.last
  end

  describe '#perform' do
    it 'ingests a buyer text message' do
      perform(
        conversation_id: 'c1', message_id: 'm1', index: '1', type: 'TEXT',
        content: { content: 'hello there' }.to_json, is_visible: true,
        sender: { im_user_id: 'u1', role: 'BUYER', nickname: 'Buyer' }
      )

      expect(last_message.content).to eq('hello there')
      expect(last_message.message_type).to eq('incoming')
    end

    it 'enqueues contact profile enrichment for the buyer (webhook lacks name/avatar)' do
      expect(Tiktok::Shop::ContactProfileJob).to receive(:perform_later)
        .with(hash_including(conversation_id: 'c1', im_user_id: 'u1'))

      perform(
        conversation_id: 'c1', message_id: 'm1', index: '1', type: 'TEXT',
        content: { content: 'hi' }.to_json, is_visible: true,
        sender: { im_user_id: 'u1', role: 'BUYER' }
      )
    end

    it 'skips invisible messages (rating requests and similar system noise)' do
      perform(
        conversation_id: 'c1', message_id: 'm3', index: '3', type: 'TEXT',
        content: { content: 'rate us' }.to_json, is_visible: false,
        sender: { im_user_id: 'u1', role: 'BUYER' }
      )

      expect(inbox.conversations.last).to be_nil
    end
  end

  describe 'image/video media' do
    let(:media_url) { 'https://tiktok-cdn.local/sample.png' }

    let(:image_data) do
      {
        conversation_id: 'c1', message_id: 'm4', index: '4', type: 'IMAGE',
        content: { url: media_url, width: '304', height: '290' }.to_json,
        is_visible: true, sender: { im_user_id: 'u1', role: 'BUYER' }
      }
    end

    it 'downloads the bytes into storage instead of persisting the ephemeral url' do
      stub_request(:get, media_url)
        .to_return(status: 200, body: 'imagedata', headers: { 'Content-Type' => 'image/png' })

      perform(image_data)

      attachment = last_message.attachments.last
      expect(attachment.file_type).to eq('image')
      expect(attachment.file.attached?).to be(true)
      expect(attachment.external_url).to be_nil
    end

    it 'falls back to external_url when the download fails' do
      stub_request(:get, media_url).to_raise(Down::Error.new('boom'))

      perform(image_data)

      attachment = last_message.attachments.last
      expect(attachment.file_type).to eq('image')
      expect(attachment.external_url).to eq(media_url)
    end
  end

  describe 'outbound echo (agent/seller message sent from the TikTok side)' do
    # Establish a conversation the way it happens in production: the buyer messages
    # first, then the shop side replies (which arrives as an echo on the webhook).
    def buyer_opens_conversation
      perform(
        conversation_id: 'c1', message_id: 'buyer-1', index: '1', type: 'TEXT',
        content: { content: 'hi, is this in stock?' }.to_json, is_visible: true,
        sender: { im_user_id: 'u1', role: 'BUYER' }
      )
    end

    def echo(role:, message_id: 'echo-1', content: 'sure, it is!')
      perform(
        conversation_id: 'c1', message_id: message_id, index: '2', type: 'TEXT',
        content: { content: content }.to_json, is_visible: true,
        sender: { im_user_id: 'shop-1', role: role }
      )
    end

    %w[SHOP CUSTOMER_SERVICE ROBOT].each do |role|
      it "mirrors a #{role} message into the thread as an outgoing echo" do
        buyer_opens_conversation
        echo(role: role)

        msg = last_message
        expect(msg.content).to eq('sure, it is!')
        expect(msg.message_type).to eq('outgoing')
        expect(msg.status).to eq('delivered')
        expect(msg.sender).to be_nil
        expect(msg.content_attributes['external_echo']).to be(true)
      end
    end

    it 'skips an echo when the buyer has no existing conversation yet' do
      echo(role: 'SHOP')

      expect(inbox.conversations.last).to be_nil
    end

    it 'dedups an echo of a message we already have by source_id (our own Chatwoot sends)' do
      buyer_opens_conversation
      echo(role: 'SHOP', message_id: 'dup-1')

      expect { echo(role: 'SHOP', message_id: 'dup-1', content: 'sure, it is!') }
        .not_to(change { inbox.conversations.last.messages.count })
    end

    it 'attaches the echo to the latest conversation when an older resolved one shares the tiktok id' do
      buyer_opens_conversation
      old_conversation = inbox.conversations.last
      old_conversation.update!(status: :resolved)
      # Buyer messages again after resolution -> a fresh conversation with the same tiktok id.
      buyer_opens_conversation
      new_conversation = inbox.conversations.order(:created_at).last
      expect(new_conversation).not_to eq(old_conversation)

      echo(role: 'SHOP')

      expect(new_conversation.messages.last.content).to eq('sure, it is!')
      expect(old_conversation.messages.reload.none? { |m| m.content_attributes['external_echo'] }).to be(true)
    end

    it 'still drops SYSTEM messages even when a conversation exists' do
      buyer_opens_conversation

      expect do
        perform(
          conversation_id: 'c1', message_id: 'sys-1', index: '3', type: 'NOTIFICATION',
          content: { content: 'buyer entered' }.to_json, is_visible: true,
          sender: { im_user_id: 'sys', role: 'SYSTEM' }
        )
      end.not_to(change { inbox.conversations.last.messages.count })
    end
  end

  describe 'service / system enter events' do
    # These are platform-generated (role SYSTEM) and should NOT create conversations
    # or messages — they were previously ingested as "context" but are just noise.
    %w[BUYER_ENTER_FROM_TRANSFER BUYER_ENTER_FROM_PRODUCT BUYER_ENTER_FROM_ORDER ALLOCATED_SERVICE NOTIFICATION].each do |type|
      it "ignores #{type} system messages" do
        perform(
          conversation_id: 'c1', message_id: "m-#{type}", index: '5', type: type,
          content: { content: 'system note', product_id: '1', order_id: '2' }.to_json,
          is_visible: true, sender: { im_user_id: 'sys', role: 'SYSTEM' }
        )

        expect(inbox.conversations.last).to be_nil
      end
    end
  end
end
