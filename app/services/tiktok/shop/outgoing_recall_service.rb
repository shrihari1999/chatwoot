# Agent-initiated recall of a previously-sent TikTok Shop message.
#
# TODO: TikTok Shop API may not support recalling messages sent via the
# Customer Service API. The publicly-available EcomPHP SDK (CustomerService.php)
# exposes only send/list/read endpoints — no recall. Until Partner Center docs
# confirm a recall endpoint, this service performs a no-op and logs the attempt.
#
# Consistent with Lazada::OutgoingRecallService in interface and lifecycle so the
# wiring in Message.trigger_tiktok_shop_recall + Tiktok::Shop::RecallJob mirrors
# Lazada exactly.
class Tiktok::Shop::OutgoingRecallService
  pattr_initialize [:message!]

  def perform
    return if message.source_id.blank?
    return unless tiktok_shop_channel?

    # TODO: replace with real Client#recall_message(...) call when the endpoint
    # is verified in Partner Center docs.
    Rails.logger.warn "[TikTok Shop Recall] Recall is not yet wired — would recall message #{message.source_id}"
  end

  private

  def tiktok_shop_channel?
    message.inbox.channel_type == 'Channel::TiktokShop'
  end
end
