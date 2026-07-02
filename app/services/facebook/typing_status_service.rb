# frozen_string_literal: true

# Calls Facebook's Messenger Platform sender_action=typing_on/typing_off API when
# an agent starts or stops typing in a Facebook conversation, showing the typing
# indicator to the buyer.
# Ref: https://developers.facebook.com/docs/messenger-platform/send-messages/sender-actions
class Facebook::TypingStatusService
  pattr_initialize [:conversation!, :typing_status!]

  def perform
    return unless facebook_channel?
    return if instagram_dm?
    return if recipient_psid.blank?
    return if sender_action.blank?

    send_sender_action
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

  def sender_action
    case typing_status.to_s
    when 'on' then 'typing_on'
    when 'off' then 'typing_off'
    end
  end

  def send_sender_action
    Facebook::Messenger::Bot.deliver(
      {
        recipient: { id: recipient_psid },
        sender_action: sender_action
      },
      page_id: channel.page_id
    )
  rescue Facebook::Messenger::FacebookError => e
    Rails.logger.warn "[Facebook TypingStatus] Failed to send #{sender_action} for conversation #{conversation.id}: #{e.message}"
  end
end
