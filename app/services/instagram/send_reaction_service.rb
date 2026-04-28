# frozen_string_literal: true

# Sends a reaction (react/unreact) on behalf of an agent via the Instagram
# Graph API. Mirrors error handling from Instagram::BaseSendService, including
# the error_code == 190 channel.authorization_error! flow. Failures are
# re-raised so callers can avoid persisting a local reaction that the customer
# never saw.
class Instagram::SendReactionService
  pattr_initialize [:message!, :emoji, :action!]

  def perform
    return false if recipient_id.blank? || message_id.blank?

    response = HTTParty.post(
      "https://graph.instagram.com/#{api_version}/#{instagram_id}/messages",
      body: payload,
      query: { access_token: channel.access_token }
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

    # https://developers.facebook.com/docs/messenger-platform/error-codes
    # Access token has expired or become invalid.
    channel.authorization_error! if error_code == 190

    Rails.logger.error("Instagram reaction response: #{error_code} - #{error_message}")
    raise StandardError, "Instagram reaction failed: #{error_code} - #{error_message}"
  end
end
