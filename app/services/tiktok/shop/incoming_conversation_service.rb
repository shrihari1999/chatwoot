# Handles the "new conversation" webhook (event type 13). Per the docs this
# fires when a customer-service agent joins or leaves a conversation, with a
# recommendation to "refresh the conversation list".
#
# We don't create a Chatwoot conversation here — that happens lazily when the
# first message arrives via the new-message webhook. We simply record the
# event on the existing conversation if we already have one, so an agent can
# tell that human CS joined/left on the TikTok side.
class Tiktok::Shop::IncomingConversationService
  pattr_initialize [:channel!, :payload!]

  def perform
    return if data.blank?

    conversation = ::Conversation.joins(:contact_inbox)
                                 .where(inbox_id: channel.inbox.id)
                                 .where("conversations.additional_attributes->>'tiktok_shop_conversation_id' = ?",
                                        data[:conversation_id].to_s)
                                 .first
    return if conversation.blank?

    Rails.logger.info "[TikTok Shop] CS agent joined/left conversation #{conversation.id}"
    # Future: dispatch a Conversations::UpdateMessageStatusJob or write an
    # activity message once the docs clarify whether 13 carries join vs leave.
  end

  private

  def data
    @data ||= payload[:data] || payload
  end
end
