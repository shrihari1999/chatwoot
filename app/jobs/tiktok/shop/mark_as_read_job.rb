# Async wrapper around Tiktok::Shop::MarkAsReadService. Enqueued from
# Api::V1::Accounts::ConversationsController when an agent opens a TikTok Shop
# conversation.
class Tiktok::Shop::MarkAsReadJob < ApplicationJob
  queue_as :default

  def perform(conversation)
    Tiktok::Shop::MarkAsReadService.new(conversation: conversation).perform
  end
end
