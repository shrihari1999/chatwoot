# == Schema Information
#
# Table name: channel_tiktok_shop
#
#  id                          :bigint           not null, primary key
#  access_token                :text             not null
#  access_token_expires_at     :datetime
#  authorization_error_count   :integer          default(0)
#  refresh_token               :text             not null
#  refresh_token_expires_at    :datetime
#  region                      :string           default("others")
#  seller_name                 :string
#  shop_cipher                 :string           not null
#  shop_id                     :string           not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :integer          not null
#
# Indexes
#
#  index_channel_tiktok_shop_on_account_id   (account_id)
#  index_channel_tiktok_shop_on_shop_cipher  (shop_cipher) UNIQUE
#  index_channel_tiktok_shop_on_shop_id      (shop_id) UNIQUE
#
class Channel::TiktokShop < ApplicationRecord
  include Channelable
  include Reauthorizable

  self.table_name = 'channel_tiktok_shop'

  # OAuth is initiated and re-initiated through the dashboard UI; user-editable
  # attributes are limited to what the OAuth callback will write back. There's no
  # form-driven editing of app_key/app_secret on the channel itself — those live
  # in Super Admin as global config (TIKTOK_SHOP_APP_KEY / TIKTOK_SHOP_APP_SECRET).
  EDITABLE_ATTRS = [].freeze

  if Chatwoot.encryption_configured?
    encrypts :access_token
    encrypts :refresh_token
  end

  AUTHORIZATION_ERROR_THRESHOLD = 1

  validates :shop_id, uniqueness: true, presence: true
  validates :shop_cipher, uniqueness: true, presence: true
  validates :access_token, presence: true
  validates :refresh_token, presence: true

  def name
    'TikTok Shop'
  end

  # Returns a non-expired access token, refreshing through TokenService if the
  # current one is within the expiry buffer window. Every API call should funnel
  # through this rather than reading `access_token` directly.
  def validated_access_token
    Tiktok::Shop::TokenService.new(channel: self).access_token
  end
end
