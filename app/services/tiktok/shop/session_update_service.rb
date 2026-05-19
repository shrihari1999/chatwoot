# Handles MESSAGE_READ webhook events from TikTok Shop. Marks Chatwoot
# messages older than the buyer's last-read timestamp as read so the agent UI
# can show read receipts.
#
# TODO: the exact payload field that conveys the "last read at" timestamp is
# undocumented in public sources. Common candidates: `last_read_message_id`,
# `last_read_at`, `read_watermark_ms`. Confirm against Partner Center docs.
class Tiktok::Shop::SessionUpdateService
  pattr_initialize [:channel!, :payload!]

  def perform
    return unless conversation
    return if watermark.blank?

    timestamp = Time.zone.at(watermark.to_i / 1000.0).utc
    ::Conversations::UpdateMessageStatusJob.perform_later(conversation.id, timestamp)
  end

  private

  def data
    @data ||= payload[:data] || payload
  end

  def conversation_external_id
    data[:conversation_id]
  end

  def watermark
    data[:read_watermark_ms] || data[:last_read_at] || data[:timestamp]
  end

  def conversation
    @conversation ||= Conversation.joins(:contact_inbox)
                                  .where(inbox_id: channel.inbox.id)
                                  .where("conversations.additional_attributes->>'tiktok_shop_conversation_id' = ?",
                                         conversation_external_id.to_s)
                                  .first
  end
end
