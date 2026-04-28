# frozen_string_literal: true

# Sends a reaction (react/unreact) on behalf of an agent via the Messenger Send API.
# Failures are tracked via ChatwootExceptionTracker and re-raised so callers can
# surface a non-2xx response and avoid persisting a local reaction that the
# customer never saw.
class Facebook::SendReactionService
  pattr_initialize [:message!, :emoji, :action!]

  def perform
    return false if recipient_id.blank? || message_id.blank?

    Facebook::Messenger::Bot.deliver(payload, page_id: channel.page_id)
    true
  rescue Facebook::Messenger::FacebookError => e
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

  def payload
    Messaging::ReactionPayloadBuilder.new(
      recipient_id: recipient_id,
      message_id: message_id,
      emoji: emoji,
      action: action
    ).build
  end
end
