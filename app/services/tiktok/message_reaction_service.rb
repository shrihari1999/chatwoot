# frozen_string_literal: true

# Applies inbound reaction events from TikTok Business Messaging to existing
# Chatwoot messages. Reactions ride inside `im_send_msg` / `im_receive_msg`
# webhooks with content[:type] == 'reaction' and a content[:reaction] array.
# Ref: https://business-api.tiktok.com/portal/docs?id=1832190670631937
class Tiktok::MessageReactionService
  include Tiktok::MessagingHelpers

  pattr_initialize [:channel!, :content!]

  def perform
    return if reactions.blank?

    reactions.each { |reaction| apply_one(reaction) }
  end

  private

  def reactions
    content[:reaction]
  end

  def tt_conversation_id
    content[:conversation_id]
  end

  def apply_one(reaction)
    # AI_EMOJI items expose only a 30-day URL, which doesn't fit Chatwoot's
    # emoji-keyed reaction bucket. Skip for now; reconsider if customers rely on it.
    if reaction[:type] != 'EMOJI'
      Rails.logger.info "[Tiktok Reaction] Skipping non-EMOJI reaction type=#{reaction[:type]}"
      return
    end

    message = find_message(tt_conversation_id, reaction[:original_msg_id])
    return if message.blank?

    message.apply_reaction!(
      emoji: reaction[:emoji],
      sender_id: reaction[:unique_identifier],
      action: reaction[:operation] == 'ADD' ? 'react' : 'unreact'
    )
  end
end
