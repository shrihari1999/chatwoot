class Lazada::SessionUpdateService
  pattr_initialize [:inbox!, :params!]

  def perform
    unless conversation
      Rails.logger.warn "[Lazada SessionUpdate] No conversation found for session_id: #{session_id}"
      return
    end

    Rails.logger.info "[Lazada SessionUpdate] Processing conversation #{conversation.id}, to_position: #{to_position}"

    # Update read status for messages based on to_position
    update_message_read_status if to_position.present?
    
    # Update conversation's unread count
    update_conversation_unread_count if unread_count_changed?
  end

  private

  def conversation
    @conversation ||= begin
      # Find conversation by Lazada session_id stored in additional_attributes
      Conversation.joins(:contact_inbox)
                  .where(inbox_id: inbox.id)
                  .where("conversations.additional_attributes->>'lazada_session_id' = ?", session_id)
                  .first
    end
  end

  def data
    @data ||= params[:data] || params
  end

  def session_id
    @session_id ||= data[:session_id]
  end

  def to_position
    @to_position ||= data[:to_position]
  end

  def unread_count
    @unread_count ||= data[:unread_count].to_i
  end

  def unread_count_changed?
    conversation.unread_count != unread_count
  end

  def update_message_read_status
    # to_position is a timestamp (milliseconds)
    # Mark all outgoing messages sent before this timestamp as 'read'
    timestamp = Time.zone.at(to_position / 1000.0)
    
    messages_to_update = conversation.messages
                                    .where(message_type: :outgoing)
                                    .where(status: 'sent')
                                    .where('created_at <= ?', timestamp)
    
    Rails.logger.info "[Lazada SessionUpdate] Marking #{messages_to_update.count} messages as read" if messages_to_update.count > 0
    
    messages_to_update.find_each do |message|
      Messages::StatusUpdateService.new(message, 'read').perform
    end
  end

  def update_conversation_unread_count
    # This unread_count is from Lazada's perspective
    conversation.update(
      additional_attributes: conversation.additional_attributes.merge(
        'lazada_unread_count' => unread_count
      )
    )
  end
end
