# frozen_string_literal: true

# Calls TikTok Business Messaging's sender_action=MARK_READ API when an agent
# views a TikTok conversation, displaying the "Seen" receipt to the customer.
# Ref: https://business-api.tiktok.com/portal/docs?id=1832184403754242
class Tiktok::MarkAsReadService
  pattr_initialize [:conversation!]

  def perform
    return unless tiktok_channel?
    return if tt_conversation_id.blank?

    mark_read
  end

  private

  def tiktok_channel?
    conversation.inbox.channel_type == 'Channel::Tiktok'
  end

  def channel
    @channel ||= conversation.inbox.channel
  end

  def tt_conversation_id
    @tt_conversation_id ||= conversation.additional_attributes&.fetch('conversation_id', nil)
  end

  def mark_read
    Tiktok::Client.new(
      business_id: channel.business_id,
      access_token: channel.validated_access_token
    ).mark_conversation_read(tt_conversation_id)
  rescue StandardError => e
    Rails.logger.warn "[Tiktok MarkAsRead] Failed to mark conversation #{conversation.id} as read: #{e.message}"
  end
end
