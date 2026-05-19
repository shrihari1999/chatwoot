# Handles inbound MESSAGE_RECALLED webhook events from TikTok Shop. Marks the
# message as deleted so it shows as a tombstone in the agent UI.
#
# Only incoming messages are processed — otherwise the
# after_update_commit :trigger_tiktok_shop_recall callback (see Message model)
# would fire and enqueue a recursive recall to the TikTok API.
class Tiktok::Shop::IncomingRecallService
  pattr_initialize [:channel!, :payload!]

  def perform
    return if data.blank?
    return if data[:message_id].blank?

    message_to_delete = channel.inbox.messages.find_by(source_id: data[:message_id].to_s)
    return if message_to_delete.blank?
    return unless message_to_delete.incoming?

    ActiveRecord::Base.transaction do
      message_to_delete.attachments.destroy_all
      message_to_delete.update!(content: I18n.t('conversations.messages.deleted'), deleted: true)
    end
  end

  private

  def data
    @data ||= payload[:data] || payload
  end
end
