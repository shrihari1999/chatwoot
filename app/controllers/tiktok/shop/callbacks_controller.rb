# Handles the TikTok Shop OAuth callback.
#
# Flow:
#   1. Validate state JWT → resolve account_id
#   2. Exchange ?code for access_token + refresh_token (does NOT include shop_cipher)
#   3. Call Get Authorized Shops with the access_token to fetch shop_cipher
#   4. Create one Channel::TiktokShop per authorized shop (MVP: just the first)
#   5. Redirect to inbox setup
class Tiktok::Shop::CallbacksController < ApplicationController
  include Tiktok::Shop::IntegrationHelper

  def show
    return handle_authorization_error if params[:error].present?

    process_successful_authorization
  rescue StandardError => e
    handle_error(e)
  end

  private

  def process_successful_authorization
    inbox, already_exists = find_or_create_inbox

    if already_exists
      redirect_to app_tiktok_shop_inbox_settings_url(account_id: account_id, inbox_id: inbox.id)
    else
      redirect_to app_tiktok_shop_inbox_agents_url(account_id: account_id, inbox_id: inbox.id)
    end
  end

  def handle_error(error)
    Rails.logger.error("TikTok Shop channel creation Error: #{error.message}")
    ChatwootExceptionTracker.new(error).capture_exception
    redirect_to_error_page(error_type: error.class.name, code: 500, error_message: error.message)
  end

  def handle_authorization_error
    redirect_to_error_page(
      error_type: params[:error] || 'access_denied',
      code: params[:error_code],
      error_message: params[:error_description] || 'User cancelled the Authorization'
    )
  end

  def redirect_to_error_page(error_type:, code:, error_message:)
    redirect_to app_new_tiktok_shop_inbox_url(
      account_id: account_id, error_type: error_type, code: code, error_message: error_message
    )
  end

  def find_or_create_inbox
    shop_attrs = primary_shop_attrs
    channel = Channel::TiktokShop.find_by(shop_id: shop_attrs[:shop_id], account: account)
    channel_exists = channel.present?

    if channel
      channel.update!(shop_attrs)
      channel.inbox.update!(name: shop_attrs[:seller_name].presence || channel.inbox.name)
    else
      channel = create_channel_with_inbox(shop_attrs)
    end

    channel.reauthorized!
    [channel.inbox, channel_exists]
  end

  def create_channel_with_inbox(shop_attrs)
    ActiveRecord::Base.transaction do
      channel = Channel::TiktokShop.create!(shop_attrs.merge(account: account))
      account.inboxes.create!(
        account: account,
        channel: channel,
        name: shop_attrs[:seller_name].presence || "TikTok Shop #{shop_attrs[:shop_id]}"
      )
      channel
    end
  end

  # The token-exchange response does not include shop_cipher; we get it by
  # calling Get Authorized Shops. For MVP we pick the first shop; multi-shop
  # support (one Chatwoot inbox per shop) is a follow-up.
  def primary_shop_attrs
    @primary_shop_attrs ||= begin
      token = token_response
      shops = Tiktok::Shop::AuthClient.fetch_authorized_shops(token[:access_token])
      raise 'No authorized shops returned from TikTok Shop' if shops.empty?

      shop = shops.first
      {
        shop_id: shop[:id].to_s,
        shop_cipher: shop[:cipher],
        seller_name: shop[:name].presence || token[:seller_name],
        region: shop[:region].presence || token[:seller_base_region] || 'others',
        access_token: token[:access_token],
        refresh_token: token[:refresh_token],
        access_token_expires_at: token[:access_token_expires_at],
        refresh_token_expires_at: token[:refresh_token_expires_at]
      }
    end
  end

  def token_response
    @token_response ||= Tiktok::Shop::AuthClient.obtain_access_token(params[:code])
  end

  def account_id
    @account_id ||= verify_tiktok_shop_token(params[:state])
  end

  def account
    @account ||= Account.find(account_id)
  end
end
