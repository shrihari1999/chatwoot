# Verifies + dispatches TikTok Shop webhook events.
#
# Event types are NUMERIC integers; the messaging-relevant ones are:
#   13 — new conversation (CS agent joined/left, refresh conversation list)
#   14 — new message (in a customer-service conversation; this is the main one)
#   33 — new message listener (creator→seller messages, different shape)
#
# Webhook payload shape:
#   { "type": 14, "tts_notification_id": "...", "shop_id": "...",
#     "timestamp": <unix-ts>, "data": { ... } }
class Webhooks::TiktokShopEventsJob < ApplicationJob
  queue_as :default

  EVENT_NEW_CONVERSATION    = 13
  EVENT_NEW_MESSAGE         = 14
  EVENT_NEW_MESSAGE_CREATOR = 33

  def perform(raw_body:, signature:)
    @raw_body = raw_body
    @payload  = parse_payload(raw_body)
    return if @payload.blank?

    return unless valid_channel?
    return unless valid_signature?(signature)

    dispatch_event
  end

  private

  def parse_payload(raw_body)
    JSON.parse(raw_body).with_indifferent_access
  rescue JSON::ParserError, TypeError
    {}
  end

  def valid_channel?
    @channel = Channel::TiktokShop.find_by(shop_id: @payload[:shop_id].to_s)
    return true if @channel.present? && @channel.account&.active?

    Rails.logger.warn(
      "[TikTok Shop Webhook] No active channel for shop_id=#{@payload[:shop_id].inspect}"
    )
    false
  end

  # TikTok Shop signs webhook DELIVERIES differently from outgoing API requests:
  # the signature is HMAC-SHA256(app_secret, app_key + raw_body), hex-encoded.
  # (Unlike API-request signing, there is no path, no query params, and no
  # app_secret wrapping — verified against live deliveries.) The signature is
  # delivered in the `Authorization` header.
  def valid_signature?(signature)
    return false if signature.blank?

    app_key    = GlobalConfigService.load('TIKTOK_SHOP_APP_KEY', nil)
    app_secret = GlobalConfigService.load('TIKTOK_SHOP_APP_SECRET', nil)
    return false if app_key.blank? || app_secret.blank?

    expected = OpenSSL::HMAC.hexdigest('SHA256', app_secret, "#{app_key}#{@raw_body}")
    valid = ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s.downcase)
    Rails.logger.warn('[TikTok Shop Webhook] Signature mismatch — dropping event') unless valid
    valid
  end

  def dispatch_event
    case @payload[:type].to_i
    when EVENT_NEW_MESSAGE
      Tiktok::Shop::IncomingMessageService.new(channel: @channel, payload: @payload).perform
    when EVENT_NEW_CONVERSATION
      Tiktok::Shop::IncomingConversationService.new(channel: @channel, payload: @payload).perform
    when EVENT_NEW_MESSAGE_CREATOR
      # Creator-side messaging — out of scope for the buyer-support inbox.
      Rails.logger.info '[TikTok Shop Webhook] Ignored creator message event 33'
    else
      Rails.logger.info "[TikTok Shop Webhook] Unhandled event type: #{@payload[:type]}"
    end
  end
end
