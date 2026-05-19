# Agent-initiated reaction toward a buyer's message on TikTok Shop.
#
# TODO: TikTok Shop API support for sending reactions is unverified. Until
# Partner Center docs confirm a reaction endpoint, this service performs a
# no-op and logs the attempt.
#
# Mirrors the inbound counterpart (Tiktok::Shop::IncomingReactionService) so
# the wiring is symmetric once both ends become real.
class Tiktok::Shop::OutgoingReactionService
  pattr_initialize [:message!, :emoji!]

  def perform
    return if message.source_id.blank?

    Rails.logger.warn "[TikTok Shop Reaction] Outgoing reaction is not yet wired — would react :#{emoji}: to message #{message.source_id}"
  end
end
