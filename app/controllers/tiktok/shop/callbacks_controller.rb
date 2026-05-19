# Handles the TikTok Shop OAuth callback. Mirrors Tiktok::CallbacksController
# but talks to the Shop OAuth endpoints (separate host, separate token shape).
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
      account_id: account_id,
      error_type: error_type,
      code: code,
      error_message: error_message
    )
  end

  def find_or_create_inbox
    channel = find_channel
    channel_exists = channel.present?

    if channel
      update_channel(channel)
    else
      channel = create_channel_with_inbox
    end

    channel.reauthorized!
    [channel.inbox, channel_exists]
  end

  def create_channel_with_inbox
    ActiveRecord::Base.transaction do
      channel = Channel::TiktokShop.create!(
        account: account,
        shop_id: short_term_access_token[:shop_id],
        shop_cipher: short_term_access_token[:shop_cipher],
        seller_name: short_term_access_token[:seller_name],
        region: short_term_access_token[:region],
        access_token: short_term_access_token[:access_token],
        refresh_token: short_term_access_token[:refresh_token],
        access_token_expires_at: short_term_access_token[:access_token_expires_at],
        refresh_token_expires_at: short_term_access_token[:refresh_token_expires_at]
      )

      account.inboxes.create!(
        account: account,
        channel: channel,
        name: short_term_access_token[:seller_name].presence || "TikTok Shop #{short_term_access_token[:shop_id]}"
      )

      channel
    end
  end

  def find_channel
    Channel::TiktokShop.find_by(shop_id: short_term_access_token[:shop_id], account: account)
  end

  def update_channel(channel)
    channel.update!(
      shop_cipher: short_term_access_token[:shop_cipher],
      seller_name: short_term_access_token[:seller_name],
      region: short_term_access_token[:region],
      access_token: short_term_access_token[:access_token],
      refresh_token: short_term_access_token[:refresh_token],
      access_token_expires_at: short_term_access_token[:access_token_expires_at],
      refresh_token_expires_at: short_term_access_token[:refresh_token_expires_at]
    )

    channel.inbox.update!(name: short_term_access_token[:seller_name].presence || channel.inbox.name)
  end

  def account_id
    @account_id ||= verify_tiktok_shop_token(params[:state])
  end

  def account
    @account ||= Account.find(account_id)
  end

  def short_term_access_token
    @short_term_access_token ||= Tiktok::Shop::AuthClient.obtain_short_term_access_token(params[:code])
  end
end
