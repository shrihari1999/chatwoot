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
  end

  private

  def conversation
    # Find conversation by Lazada session_id stored in additional_attributes
    @conversation ||= Conversation.joins(:contact_inbox)
                                  .where(inbox_id: inbox.id)
                                  .where("conversations.additional_attributes->>'lazada_session_id' = ?", session_id)
                                  .first
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

  def update_message_read_status
    # to_position is a timestamp in milliseconds; enqueue async job as other channels do
    timestamp = Time.zone.at(to_position.to_i / 1000.0).utc
    ::Conversations::UpdateMessageStatusJob.perform_later(conversation.id, timestamp)
  end
end
