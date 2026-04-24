# frozen_string_literal: true

# Handles incoming LINE "read" webhook events.
# When a customer reads OA messages, LINE sends a read event with a timestamp.
# This marks outbound messages created before that timestamp as :read in Chatwoot.
# Mirrors Instagram::ReadStatusService and Tiktok::ReadStatusService.
class Line::ReadStatusService
  pattr_initialize [:inbox!, :event!]

  def perform
    return if conversation.blank?

    ::Conversations::UpdateMessageStatusJob.perform_later(conversation.id, read_timestamp)
  end

  private

  def conversation
    @conversation ||= begin
      contact_inbox = inbox.contact_inboxes.find_by(source_id: user_id)
      return if contact_inbox.blank?

      # Mirror Line::IncomingMessageService#set_conversation:
      # when lock_to_single_conversation is off, prefer the latest unresolved thread.
      if inbox.lock_to_single_conversation
        contact_inbox.conversations.last
      else
        contact_inbox.conversations.where.not(status: :resolved).last ||
          contact_inbox.conversations.last
      end
    end
  end

  def user_id
    event.dig('source', 'userId')
  end

  def read_timestamp
    # LINE timestamp is in milliseconds
    Time.zone.at(event['timestamp'].to_i / 1000.0).utc
  end
end
