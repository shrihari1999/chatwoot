# Outgoing reaction handler.
#
# **TikTok Shop API does not support sending reactions on customer-service
# messages.** Kept as a no-op for symmetry with the inbound counterpart.
class Tiktok::Shop::OutgoingReactionService
  pattr_initialize [:message!, :emoji!]

  def perform
    Rails.logger.info "[TikTok Shop] Outbound reactions are not supported by the TikTok Shop API"
  end
end
