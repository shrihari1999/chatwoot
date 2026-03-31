class Lazada::SessionUpdateService
  pattr_initialize [:inbox!, :params!]

  def perform
    Rails.logger.info "[Lazada SessionUpdate] Processing webhook for inbox: #{inbox.id}"
    Rails.logger.info "[Lazada SessionUpdate] Params: #{data.inspect}"
    
    unless conversation
      Rails.logger.warn "[Lazada SessionUpdate] No conversation found for session_id: #{session_id}"
      return
    end

    Rails.logger.info "[Lazada SessionUpdate] Found conversation: #{conversation.id}"
    Rails.logger.info "[Lazada SessionUpdate] to_position: #{to_position}, self_position: #{data[:self_position]}"

    # Update read status for messages based on to_position
    if to_position.present?
      update_message_read_status
    else
      Rails.logger.warn "[Lazada SessionUpdate] No to_position provided"
    end
    
    # Update conversation's unread count
    update_conversation_unread_count if unread_count_changed?
  end

  private

  def conversation
    @conversation ||= begin
      # Find conversation by Lazada session_id stored in additional_attributes
      conv = Conversation.joins(:contact_inbox)
                         .where(inbox_id: inbox.id)
                         .where("conversations.additional_attributes->>'lazada_session_id' = ?", session_id)
                         .first
      Rails.logger.info "[Lazada SessionUpdate] Conversation lookup for session_id: #{session_id} - #{conv ? "Found (#{conv.id})" : 'Not found'}"
      conv
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
    
    Rails.logger.info "[Lazada SessionUpdate] Looking for outgoing messages before: #{timestamp}"
    
    messages_to_update = conversation.messages
                                    .where(message_type: :outgoing)
                                    .where(status: 'sent')
                                    .where('created_at <= ?', timestamp)
    
    Rails.logger.info "[Lazada SessionUpdate] Found #{messages_to_update.count} messages to mark as read"
    
    messages_to_update.find_each do |message|
      Rails.logger.info "[Lazada SessionUpdate] Marking message #{message.id} (created_at: #{message.created_at}) as read"
      Messages::StatusUpdateService.new(message, 'read').perform
    end
  end

  def update_conversation_unread_count
    Rails.logger.info "[Lazada SessionUpdate] Updating unread_count from #{conversation.unread_count} to #{unread_count}"
    # This unread_count is from Lazada's perspective
    # We might want to update our internal unread count as well
    conversation.update(
      additional_attributes: conversation.additional_attributes.merge(
        'lazada_unread_count' => unread_count
      )
    )
  end
end
