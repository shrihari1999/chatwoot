# frozen_string_literal: true

FactoryBot.define do
  factory :channel_tiktok_shop, class: 'Channel::TiktokShop' do
    shop_id { SecureRandom.uuid }
    shop_cipher { SecureRandom.uuid }
    seller_name { 'TheRollingPinn' }
    region { 'others' }
    access_token { SecureRandom.uuid }
    refresh_token { SecureRandom.uuid }
    access_token_expires_at { 1.day.from_now }
    refresh_token_expires_at { 1.year.from_now }
    inbox
    account
  end
end
