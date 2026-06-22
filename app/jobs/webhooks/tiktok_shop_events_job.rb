# Verifies + dispatches TikTok Shop webhook events.
#
# Event types are NUMERIC integers; the ones we handle are:
#   7  — upcoming authorization expiration (fires daily, 30 days before expiry)
#   13 — new conversation (CS agent joined/left, refresh conversation list)
#   14 — new message (in a customer-service conversation; this is the main one)
#   33 — new message listener (creator→seller messages, different shape)
#
# Webhook payload shape:
#   { "type": 14, "tts_notification_id": "...", "shop_id": "...",
#     "timestamp": <unix-ts>, "data": { ... } }
class Webhooks::TiktokShopEventsJob < ApplicationJob
  queue_as :default

  EVENT_AUTH_EXPIRING       = 7
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

  # Defense-in-depth: the controller already rejects bad signatures with 401, but
  # re-verify here in case the job is enqueued from elsewhere. Algorithm lives in
  # Tiktok::Shop::WebhookSignatureService (HMAC-SHA256(app_secret, app_key + body)).
  def valid_signature?(signature)
    return true if Tiktok::Shop::WebhookSignatureService.valid?(raw_body: @raw_body, signature: signature)

    Rails.logger.warn('[TikTok Shop Webhook] Signature mismatch — dropping event')
    false
  end

  def dispatch_event
    case @payload[:type].to_i
    when EVENT_NEW_MESSAGE
      Tiktok::Shop::IncomingMessageService.new(channel: @channel, payload: @payload).perform
    when EVENT_NEW_CONVERSATION
      Tiktok::Shop::IncomingConversationService.new(channel: @channel, payload: @payload).perform
    when EVENT_AUTH_EXPIRING
      handle_authorization_expiring
    when EVENT_NEW_MESSAGE_CREATOR
      # Creator-side messaging — out of scope for the buyer-support inbox.
      Rails.logger.info '[TikTok Shop Webhook] Ignored creator message event 33'
    else
      Rails.logger.info "[TikTok Shop Webhook] Unhandled event type: #{@payload[:type]}"
    end
  end

  # Event 7 fires daily starting 30 days before the shop's authorization expires.
  # Flag the channel so the dashboard shows the re-authorization prompt, giving
  # advance notice to re-connect before the grant lapses and the API stops working.
  def handle_authorization_expiring
    @channel.prompt_reauthorization!
    Rails.logger.warn(
      "[TikTok Shop Webhook] Authorization expiring for shop_id=#{@payload[:shop_id]} " \
      "(#{@payload.dig(:data, :message)}) — flagged for re-authorization"
    )
  end
end
