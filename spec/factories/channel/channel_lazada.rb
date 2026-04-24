# frozen_string_literal: true

FactoryBot.define do
  factory :channel_lazada, class: 'Channel::Lazada' do
    shop_id { SecureRandom.uuid }
    app_key { SecureRandom.uuid }
    app_secret { SecureRandom.uuid }
    access_token { SecureRandom.uuid }
    inbox
    account
  end
end
