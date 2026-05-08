# frozen_string_literal: true

# Sends a reaction (react/unreact) on behalf of an agent via the Instagram
# Graph API. Instagram supports sender_action=react via POST to /<IG_ID>/messages.
# Refs: https://developers.facebook.com/docs/messenger-platform/instagram/features/send-message/
#       https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login/messaging-api/
#
# Failures are logged and re-raised so callers can decide how to handle them.
# Supports both Channel::Instagram and Channel::FacebookPage (Instagram DM — identified by
# instagram_id present on the FacebookPage channel). Both channel types expose
# #page_access_token for the underlying access token.
class Instagram::SendReactionService
  pattr_initialize [:message!, :emoji, :action!]

  REACT_UNREACT = 'unreact'
  HEART_EMOJI   = '❤️'

  def perform
    return false if recipient_id.blank? || message_id.blank?

    # IG-direct delivers unreact to the customer's Instagram client only when
    # the active reaction is heart. For non-heart reactions the API returns
    # 200 and /me/conversations shows the reaction cleared, but the customer's
    # phone keeps showing the pill. Workaround: edit the active reaction to
    # heart first (Meta's "edit" via react replaces any prior emoji), then
    # send the actual unreact — which the customer surface honours.
    post_reaction(react_to_heart_payload) if action == REACT_UNREACT

    response = post_reaction(payload)
    handle_response(response)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: message.account).capture_exception
    raise
  end

  private

  def channel
    @channel ||= message.conversation.inbox.channel
  end

  def recipient_id
    @recipient_id ||= message.conversation.contact.get_source_id(message.conversation.inbox_id)
  end

  def message_id
    @message_id ||= message.source_id
  end

  def api_version
    GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v22.0')
  end

  def instagram_id
    channel.instagram_id.presence || 'me'
  end

  # Channel::FacebookPage stores the token as page_access_token; Channel::Instagram
  # exposes it via access_token (which handles OAuth refresh automatically).
  def instagram_access_token
    channel.is_a?(Channel::FacebookPage) ? channel.page_access_token : channel.access_token
  end

  def payload
    Messaging::ReactionPayloadBuilder.new(
      recipient_id: recipient_id,
      message_id: message_id,
      emoji: emoji,
      action: action
    ).build
  end

  def react_to_heart_payload
    Messaging::ReactionPayloadBuilder.new(
      recipient_id: recipient_id,
      message_id: message_id,
      emoji: HEART_EMOJI,
      action: 'react'
    ).build
  end

  def post_reaction(body)
    # Form-encoded body fails for sender_action=react with subcode 2534015
    # ("Invalid message data") — the nested payload[message_id]/payload[reaction]
    # form Meta's reaction parser doesn't accept. Send as JSON with the
    # Authorization Bearer header per Meta's documented sample.
    HTTParty.post(
      "https://graph.instagram.com/#{api_version}/#{instagram_id}/messages",
      body: body.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{instagram_access_token}"
      }
    )
  end

  def handle_response(response)
    return true if response.success?

    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    error_code = parsed.dig('error', 'code')
    error_message = parsed.dig('error', 'message')

    Rails.logger.error("Instagram reaction response: #{error_code} - #{error_message}")
    raise StandardError, "Instagram reaction failed: #{error_code} - #{error_message}"
  end
end
