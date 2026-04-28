# frozen_string_literal: true

# Sends a reaction (react/unreact) on behalf of the page to a Messenger message.
#
# Refs: https://developers.facebook.com/docs/messenger-platform/send-messages/sender-actions/
#       https://developers.facebook.com/docs/graph-api/reference/page/messages/
#
# The endpoint is POST /me/messages with:
#   { recipient: {id: <PSID>}, sender_action: 'react'|'unreact',
#     payload: { message_id: <MID> [, reaction: <emoji>] } }
#
# Failures are logged and re-raised so the controller can decide how to handle them.
class Facebook::SendReactionService
  pattr_initialize [:message!, :emoji, :action!]

  def perform
    return false if recipient_psid.blank? || message_id.blank?

    Facebook::Messenger::Bot.deliver(
      Messaging::ReactionPayloadBuilder.new(
        recipient_id: recipient_psid,
        message_id: message_id,
        emoji: emoji,
        action: action
      ).build,
      page_id: channel.page_id
    )
    true
  rescue Facebook::Messenger::FacebookError => e
    ChatwootExceptionTracker.new(e, account: message.account).capture_exception
    raise
  end

  private

  def channel
    @channel ||= message.conversation.inbox.channel
  end

  def recipient_psid
    @recipient_psid ||= message.conversation.contact.get_source_id(message.conversation.inbox_id)
  end

  def message_id
    @message_id ||= message.source_id
  end
end
