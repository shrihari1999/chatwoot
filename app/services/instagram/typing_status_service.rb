# frozen_string_literal: true

# Relays an agent's typing on/off to the customer on a dedicated Instagram Login
# channel via the Instagram Graph API sender_action=typing_on/typing_off, showing
# the typing indicator in the customer's Instagram DM thread.
# Refs: https://developers.facebook.com/docs/messenger-platform/send-messages/sender-actions
#       https://developers.facebook.com/docs/instagram-platform/instagram-api-with-instagram-login/messaging-api/
#
# Only Channel::Instagram is handled here. Instagram DMs that Chatwoot models as
# Channel::FacebookPage use the Messenger transport (graph.facebook.com) and, like
# Facebook::MarkAsReadService, are intentionally left without a typing indicator —
# graph.instagram.com rejects page tokens with error 190.
class Instagram::TypingStatusService
  pattr_initialize [:conversation!, :typing_status!]

  def perform
    return unless instagram_channel?
    return if recipient_id.blank?
    return if sender_action.blank?

    send_sender_action
  end

  private

  def instagram_channel?
    conversation.inbox.channel_type == 'Channel::Instagram'
  end

  def channel
    @channel ||= conversation.inbox.channel
  end

  def recipient_id
    @recipient_id ||= conversation.contact.get_source_id(conversation.inbox_id)
  end

  def instagram_id
    channel.instagram_id.presence || 'me'
  end

  def api_version
    GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v22.0')
  end

  def sender_action
    case typing_status.to_s
    when 'on' then 'typing_on'
    when 'off' then 'typing_off'
    end
  end

  def send_sender_action
    response = HTTParty.post(
      "https://graph.instagram.com/#{api_version}/#{instagram_id}/messages",
      body: { recipient: { id: recipient_id }, sender_action: sender_action }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{channel.access_token}"
      }
    )

    handle_response(response)
  rescue StandardError => e
    Rails.logger.warn "[Instagram TypingStatus] Failed to send #{sender_action} for conversation #{conversation.id}: #{e.message}"
  end

  def handle_response(response)
    return if response.success?

    parsed = response.parsed_response.is_a?(Hash) ? response.parsed_response : {}
    Rails.logger.warn(
      "[Instagram TypingStatus] Failed to send #{sender_action} for conversation #{conversation.id}: " \
      "#{parsed.dig('error', 'code')} - #{parsed.dig('error', 'message')}"
    )
  end
end
