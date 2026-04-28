# frozen_string_literal: true

# Handles Facebook Messenger message edit webhooks.
# When a customer edits a message, this service finds the original
# message by its mid (source_id) and updates its content.
class Facebook::UpdateMessageService
  pattr_initialize [:inbox!, :response!]

  def perform
    return if response.identifier.blank?
    return if response.content.blank?

    message = inbox.messages.find_by(source_id: response.identifier)
    return if message.blank?
    return unless message.incoming?

    message.update!(content: response.content, edited: true)
  end
end
