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

  def perform
    return false if recipient_id.blank? || message_id.blank?

    response = HTTParty.post(
      "https://graph.instagram.com/#{api_version}/#{instagram_id}/messages",
      body: payload,
      query: { access_token: instagram_access_token }
    )

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

  def handle_response(response)
    return true if response.success?

    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    error_code = parsed.dig('error', 'code')
    error_message = parsed.dig('error', 'message')

    Rails.logger.error("Instagram reaction response: #{error_code} - #{error_message}")
    raise StandardError, "Instagram reaction failed: #{error_code} - #{error_message}"
  end
end
