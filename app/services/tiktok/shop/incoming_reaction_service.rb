# Inbound reaction handler.
#
# **TikTok Shop API does not surface message reactions.** Neither the
# Customer Service API endpoint set (send/list/read/upload/create) nor the
# webhook event catalogue (types 13, 14, 33 — see docs/integrations/
# TIKTOK_SHOP_INTEGRATION_PLAN.md) includes a reaction primitive.
#
# Kept as a no-op for interface symmetry with the outgoing counterpart and to
# preserve the door for a future API revision.
class Tiktok::Shop::IncomingReactionService
  pattr_initialize [:channel!, :payload!]

  def perform
    Rails.logger.info "[TikTok Shop] Inbound reactions are not supported by the TikTok Shop API"
  end
end
