# frozen_string_literal: true

# Relays an agent's typing to the customer on a TikTok Business Messaging
# conversation via sender_action=TYPING, displaying a "Typing" icon in the chat.
# Ref: https://business-api.tiktok.com/portal/docs?id=1832184403754242
#
# TikTok's TYPING action only starts the indicator — it auto-clears after ~5
# seconds and there is no stop, so we act on typing 'on' only and treat 'off'
# as a no-op.
class Tiktok::TypingStatusService
  pattr_initialize [:conversation!, :typing_status!]

  def perform
    return unless tiktok_channel?
    return unless start?
    return if tt_conversation_id.blank?

    send_typing
  end

  private

  def tiktok_channel?
    conversation.inbox.channel_type == 'Channel::Tiktok'
  end

  def start?
    typing_status.to_s == 'on'
  end

  def channel
    @channel ||= conversation.inbox.channel
  end

  def tt_conversation_id
    @tt_conversation_id ||= conversation.additional_attributes&.fetch('conversation_id', nil)
  end

  def send_typing
    Tiktok::Client.new(
      business_id: channel.business_id,
      access_token: channel.validated_access_token
    ).send_typing_action(tt_conversation_id)
  rescue StandardError => e
    Rails.logger.warn "[Tiktok TypingStatus] Failed to send typing for conversation #{conversation.id}: #{e.message}"
  end
end
