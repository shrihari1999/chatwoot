# Agent-initiated recall (Chatwoot-side "delete this message") on TikTok Shop.
#
# **Confirmed unsupported by the TikTok Shop Customer Service API.** The v202309
# customer_service endpoint surface exposes send / list / read / upload / create
# only — there is no recall, edit, or delete endpoint. See the feature-gap
# table in docs/integrations/TIKTOK_SHOP_INTEGRATION_PLAN.md.
#
# This service is kept (rather than deleted) so the Message.trigger_tiktok_shop_recall
# wiring stays parallel to Lazada's. The Chatwoot agent UI will mark the
# message deleted locally; the buyer continues to see it on TikTok Shop.
class Tiktok::Shop::OutgoingRecallService
  pattr_initialize [:message!]

  def perform
    return if message.source_id.blank?
    return unless tiktok_shop_channel?

    Rails.logger.info(
      '[TikTok Shop] Recall not supported by TikTok Shop API — ' \
      "message #{message.source_id} is removed in Chatwoot only"
    )
  end

  private

  def tiktok_shop_channel?
    message.inbox.channel_type == 'Channel::TiktokShop'
  end
end
