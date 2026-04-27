# frozen_string_literal: true

# Handles inbound Lazada recall webhooks. When Lazada pushes a message with
# status=1, the original message has been recalled by the sender (buyer or seller)
# and should be marked as deleted in Chatwoot.
class Lazada::IncomingRecallService
  pattr_initialize [:inbox!, :params!]

  def perform
    return if data.blank?
    return if data[:message_id].blank?

    message_to_delete = inbox.messages.find_by(source_id: data[:message_id].to_s)
    return if message_to_delete.blank?

    ActiveRecord::Base.transaction do
      message_to_delete.attachments.destroy_all
      message_to_delete.update!(content: I18n.t('conversations.messages.deleted'), deleted: true)
    end
  end

  private

  def data
    params[:data]
  end
end
