# Dispatches TikTok Shop webhook events to per-event services. Looks up the
# channel by shop_id, verifies the HMAC signature, and routes on the event
# `type`.
#
# TODO: confirm exact event type strings and signature header name + signing
# format against Partner Center docs. The names below are placeholders inferred
# from the API style.
class Webhooks::TiktokShopEventsJob < ApplicationJob
  queue_as :default

  EVENT_MESSAGE_NEW       = 'MESSAGE_NEW'.freeze          # TODO: verify
  EVENT_MESSAGE_READ      = 'MESSAGE_READ'.freeze         # TODO: verify
  EVENT_MESSAGE_RECALLED  = 'MESSAGE_RECALLED'.freeze     # TODO: verify
  EVENT_MESSAGE_REACTION  = 'MESSAGE_REACTION'.freeze     # TODO: verify
  EVENT_CONVERSATION_UPDATED = 'CONVERSATION_UPDATED'.freeze # TODO: verify

  def perform(raw_body:, signature:, timestamp: nil)
    @raw_body = raw_body
    @payload = parse_payload(raw_body)
    return if @payload.blank?

    return unless valid_channel?
    return unless valid_signature?(signature, timestamp)

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
    @channel.present? && @channel.account&.active?
  end

  # TikTok Shop's signature scheme is undocumented in publicly-accessible sources
  # but the standard convention across their developer surfaces is:
  #     HMAC-SHA256(app_secret, "<timestamp>.<raw_body>")
  # encoded as lowercase hex. TODO: verify against live deliveries — see
  # Tiktok Business Messaging signing in app/controllers/webhooks/tiktok_controller.rb
  # for the same idiom.
  def valid_signature?(signature, timestamp)
    return false if signature.blank?

    app_secret = GlobalConfigService.load('TIKTOK_SHOP_APP_SECRET', nil)
    return false if app_secret.blank?

    signed_payload = "#{timestamp}.#{@raw_body}"
    expected = OpenSSL::HMAC.hexdigest('SHA256', app_secret, signed_payload)
    ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s.downcase)
  end

  def dispatch_event
    case @payload[:type] || @payload[:event]
    when EVENT_MESSAGE_NEW
      Tiktok::Shop::IncomingMessageService.new(channel: @channel, payload: @payload).perform
    when EVENT_MESSAGE_READ
      Tiktok::Shop::SessionUpdateService.new(channel: @channel, payload: @payload).perform
    when EVENT_MESSAGE_RECALLED
      Tiktok::Shop::IncomingRecallService.new(channel: @channel, payload: @payload).perform
    when EVENT_MESSAGE_REACTION
      Tiktok::Shop::IncomingReactionService.new(channel: @channel, payload: @payload).perform
    else
      Rails.logger.info "[TikTok Shop Webhook] Unhandled event type: #{@payload[:type] || @payload[:event]}"
    end
  end
end
