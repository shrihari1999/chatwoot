# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Webhooks::TiktokShop', type: :request do
  let(:app_key) { 'test_app_key' }
  let(:app_secret) { 'test_app_secret' }
  let(:body) { { type: 14, shop_id: '123' }.to_json }
  let(:valid_signature) { OpenSSL::HMAC.hexdigest('SHA256', app_secret, "#{app_key}#{body}") }

  before do
    allow(GlobalConfigService).to receive(:load).and_call_original
    allow(GlobalConfigService).to receive(:load).with('TIKTOK_SHOP_APP_KEY', nil).and_return(app_key)
    allow(GlobalConfigService).to receive(:load).with('TIKTOK_SHOP_APP_SECRET', nil).and_return(app_secret)
  end

  describe 'POST /webhooks/tiktok_shop' do
    it 'returns 200 and enqueues the events job for a valid signature' do
      expect(Webhooks::TiktokShopEventsJob).to receive(:perform_later)

      post '/webhooks/tiktok_shop', params: body,
                                    headers: { 'Authorization' => valid_signature, 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:ok)
    end

    it 'returns 401 and does not enqueue for an invalid signature' do
      expect(Webhooks::TiktokShopEventsJob).not_to receive(:perform_later)

      post '/webhooks/tiktok_shop', params: body,
                                    headers: { 'Authorization' => 'deadbeef', 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 when the signature header is missing' do
      expect(Webhooks::TiktokShopEventsJob).not_to receive(:perform_later)

      post '/webhooks/tiktok_shop', params: body, headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
