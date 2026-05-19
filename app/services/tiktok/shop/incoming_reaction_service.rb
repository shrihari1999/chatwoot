# Handles inbound reaction events from TikTok Shop.
#
# TODO: TikTok Shop API support for reactions is unverified. The public
# EcomPHP SDK does not expose reaction endpoints or document reaction webhook
# events. The user explicitly requested bidirectional reaction support — this
# service is the inbound half of that placeholder.
#
# When confirmed: store the reaction in `content_attributes` of the referenced
# message and broadcast via the existing message-update channel so the agent
# UI re-renders. See app/models/concerns/message_emoji_interactable.rb for the
# in-Chatwoot reaction storage pattern.
class Tiktok::Shop::IncomingReactionService
  pattr_initialize [:channel!, :payload!]

  def perform
    return if data.blank?

    Rails.logger.info "[TikTok Shop Reaction] Inbound reaction event received but not yet wired. data=#{data.inspect}"
    # TODO: locate the target message by source_id, attach the reaction to
    # content_attributes[:reactions], then save.
  end

  private

  def data
    @data ||= payload[:data] || payload
  end
end
