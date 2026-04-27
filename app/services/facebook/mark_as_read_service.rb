# frozen_string_literal: true

# Calls Facebook's Messenger Platform sender_action=mark_seen API when an agent
# views a Facebook conversation, showing the "seen" receipt to the buyer.
# Ref: https://developers.facebook.com/docs/messenger-platform/send-messages/sender-actions
class Facebook::MarkAsReadService
  pattr_initialize [:conversation!]

  def perform
    return unless facebook_channel?
    return if instagram_dm?
    return if recipient_psid.blank?

    mark_seen
  end

  private

  def facebook_channel?
    conversation.inbox.channel_type == 'Channel::FacebookPage'
  end

  # Channel::FacebookPage also backs Instagram Direct conversations, which use a
  # different transport (Instagram::Messenger::SendOnInstagramService). Skip
  # those here so we don't push the wrong sender_action through the Messenger API.
  def instagram_dm?
    conversation.additional_attributes['type'] == 'instagram_direct_message'
  end

  def channel
    @channel ||= conversation.inbox.channel
  end

  def recipient_psid
    @recipient_psid ||= conversation.contact.get_source_id(conversation.inbox_id)
  end

  def mark_seen
    Facebook::Messenger::Bot.deliver(
      {
        recipient: { id: recipient_psid },
        sender_action: 'mark_seen'
      },
      page_id: channel.page_id
    )
  rescue Facebook::Messenger::FacebookError => e
    Rails.logger.warn "[Facebook MarkAsRead] Failed to send mark_seen for conversation #{conversation.id}: #{e.message}"
  end
end
