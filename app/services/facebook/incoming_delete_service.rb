# frozen_string_literal: true

# Handles Facebook Messenger "unsend" events.
# When a customer deletes a message, Facebook sends a webhook with
# is_deleted: true. This service finds the original message by its
# message ID (mid) and marks it as deleted in Chatwoot.
class Facebook::IncomingDeleteService
  pattr_initialize [:inbox!, :response!]

  def perform
    return if response.identifier.blank?

    message_to_delete = inbox.messages.find_by(source_id: response.identifier)
    return if message_to_delete.blank?
    return unless message_to_delete.incoming?

    ActiveRecord::Base.transaction do
      message_to_delete.attachments.destroy_all
      message_to_delete.update!(content: I18n.t('conversations.messages.deleted'), deleted: true)
    end
  end
end
