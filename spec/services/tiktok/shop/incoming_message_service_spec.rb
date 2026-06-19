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

    it 'ignores messages from non-buyer roles that are not context events' do
      perform(
        conversation_id: 'c1', message_id: 'm2', index: '2', type: 'TEXT',
        content: { content: 'agent reply' }.to_json, is_visible: true,
        sender: { im_user_id: 's1', role: 'SHOP' }
      )

      expect(inbox.conversations.last).to be_nil
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

  describe 'buyer-context enter events' do
    it 'ingests BUYER_ENTER_FROM_PRODUCT even when the sender role is not BUYER' do
      perform(
        conversation_id: 'c1', message_id: 'm5', index: '5', type: 'BUYER_ENTER_FROM_PRODUCT',
        content: { product_id: '12345' }.to_json,
        sender: { im_user_id: 'u1', role: 'SYSTEM' }
      )

      expect(last_message.content).to eq('Buyer started chat from product 12345')
    end

    it 'ingests BUYER_ENTER_FROM_ORDER as context' do
      perform(
        conversation_id: 'c1', message_id: 'm6', index: '6', type: 'BUYER_ENTER_FROM_ORDER',
        content: { order_id: '67890' }.to_json,
        sender: { im_user_id: 'u1', role: 'SYSTEM' }
      )

      expect(last_message.content).to eq('Buyer started chat from order 67890')
    end

    it 'ingests BUYER_ENTER_FROM_TRANSFER as context' do
      perform(
        conversation_id: 'c1', message_id: 'm7', index: '7', type: 'BUYER_ENTER_FROM_TRANSFER',
        content: { content: 'transferred to support' }.to_json,
        sender: { im_user_id: 'u1', role: 'SYSTEM' }
      )

      expect(last_message.content).to eq('transferred to support')
    end
  end
end
