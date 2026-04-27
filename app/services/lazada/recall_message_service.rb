# frozen_string_literal: true

# Handles inbound Lazada recall webhooks. When Lazada pushes a message with
# status=1, the original message has been recalled by the sender and should be
# marked as deleted in Chatwoot.
class Lazada::RecallMessageService
  pattr_initialize [:inbox!, :params!]

  def perform
    recall_message if recalled_message?
  end

  private

  def data
    params[:data]
  end

  def recalled_message?
    data[:status].to_i == 1
  end

  def recall_message
    message_to_delete = inbox.messages.find_by(source_id: data[:message_id].to_s)
    return if message_to_delete.blank?

    message_to_delete.attachments.destroy_all
    message_to_delete.update!(content: I18n.t('conversations.messages.deleted'), deleted: true)
  end
end
