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
    @conversation ||= inbox.conversations
                           .joins(:contact_inbox)
                           .find_by(contact_inboxes: { source_id: user_id })
  end

  def user_id
    event.dig('source', 'userId')
  end

  def read_timestamp
    # LINE timestamp is in milliseconds
    Time.zone.at(event['timestamp'].to_i / 1000.0).utc
  end
end
