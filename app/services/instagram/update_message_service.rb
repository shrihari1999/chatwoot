# frozen_string_literal: true

# Handles Instagram message_edit webhooks (delivered under object=instagram).
# When a customer edits a DM, this finds the original message by its mid
# (source_id) and updates its content. Mirrors Facebook::UpdateMessageService.
class Instagram::UpdateMessageService
  pattr_initialize [:inbox!, :messaging!]

  def perform
    return if identifier.blank?
    return if content.blank?

    message = inbox.messages.find_by(source_id: identifier)
    return if message.blank?
    return unless message.incoming?

    message.update!(content: content, edited: true)
  end

  private

  def identifier
    messaging.dig(:message_edit, :mid)
  end

  def content
    messaging.dig(:message_edit, :text)
  end
end
