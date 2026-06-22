# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Webhooks::TiktokShopEventsJob do
  let(:account) { create(:account) }
  let!(:channel) { create(:channel_tiktok_shop, account: account, shop_id: '7494602666519137224') }
  let(:app_key) { 'test_app_key' }
  let(:app_secret) { 'test_app_secret' }

  let(:raw_body) do
    {
      type: 14, shop_id: channel.shop_id,
      data: {
        conversation_id: 'c1', message_id: 'm1', index: '1', type: 'TEXT',
        content: { content: 'Hi' }.to_json, is_visible: true,
        sender: { im_user_id: 'u1', role: 'BUYER' }
      }
    }.to_json
  end

  # TikTok Shop webhook signature = HMAC-SHA256(app_secret, app_key + raw_body), hex.
  let(:valid_signature) { OpenSSL::HMAC.hexdigest('SHA256', app_secret, "#{app_key}#{raw_body}") }

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('TIKTOK_SHOP_APP_KEY', nil).and_return(app_key)
    allow(GlobalConfigService).to receive(:load).with('TIKTOK_SHOP_APP_SECRET', nil).and_return(app_secret)
  end

  it 'dispatches to IncomingMessageService when the signature and channel are valid' do
    service = instance_double(Tiktok::Shop::IncomingMessageService, perform: nil)
    expect(Tiktok::Shop::IncomingMessageService).to receive(:new)
      .with(channel: channel, payload: kind_of(Hash)).and_return(service)

    described_class.perform_now(raw_body: raw_body, signature: valid_signature)
  end

  it 'accepts an uppercase hex signature (case-insensitive)' do
    service = instance_double(Tiktok::Shop::IncomingMessageService, perform: nil)
    expect(Tiktok::Shop::IncomingMessageService).to receive(:new).and_return(service)

    described_class.perform_now(raw_body: raw_body, signature: valid_signature.upcase)
  end

  it 'drops the event when the signature is invalid' do
    expect(Tiktok::Shop::IncomingMessageService).not_to receive(:new)

    described_class.perform_now(raw_body: raw_body, signature: 'deadbeef')
  end

  it 'drops the event when the signature is blank' do
    expect(Tiktok::Shop::IncomingMessageService).not_to receive(:new)

    described_class.perform_now(raw_body: raw_body, signature: nil)
  end

  it 'drops the event when no active channel matches the shop_id' do
    body = JSON.parse(raw_body).merge('shop_id' => 'unknown_shop').to_json
    signature = OpenSSL::HMAC.hexdigest('SHA256', app_secret, "#{app_key}#{body}")
    expect(Tiktok::Shop::IncomingMessageService).not_to receive(:new)

    described_class.perform_now(raw_body: body, signature: signature)
  end

  it 'routes new-conversation (type 13) events to IncomingConversationService' do
    body = JSON.parse(raw_body).merge('type' => 13).to_json
    signature = OpenSSL::HMAC.hexdigest('SHA256', app_secret, "#{app_key}#{body}")
    service = instance_double(Tiktok::Shop::IncomingConversationService, perform: nil)
    expect(Tiktok::Shop::IncomingConversationService).to receive(:new).and_return(service)

    described_class.perform_now(raw_body: body, signature: signature)
  end
end
