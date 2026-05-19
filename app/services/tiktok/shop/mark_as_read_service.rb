# Calls TikTok Shop's mark-conversation-read endpoint when an agent views a
# Chatwoot conversation. Mirrors Lazada::MarkAsReadService.
class Tiktok::Shop::MarkAsReadService
  pattr_initialize [:conversation!]

  def perform
    return unless tiktok_shop_channel?
    return if conversation_id.blank?

    Tiktok::Shop::Client.new(channel: conversation.inbox.channel).mark_conversation_read(conversation_id)
  end

  private

  def tiktok_shop_channel?
    conversation.inbox.channel_type == 'Channel::TiktokShop'
  end

  def conversation_id
    @conversation_id ||= conversation.additional_attributes&.fetch('tiktok_shop_conversation_id', nil)
  end
end
