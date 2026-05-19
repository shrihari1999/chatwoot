# Async wrapper around Tiktok::Shop::OutgoingRecallService. Enqueued by the
# Message after_update_commit :trigger_tiktok_shop_recall callback.
class Tiktok::Shop::RecallJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    Tiktok::Shop::OutgoingRecallService.new(message: message).perform
  end
end
