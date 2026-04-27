# frozen_string_literal: true

class Lazada::RecallJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message
    return if message.source_id.blank?

    channel = message.inbox.channel
    return unless channel.is_a?(Channel::Lazada)

    result = channel.recall_im_message(message_id: message.source_id)
    return if result.success?

    Rails.logger.warn "[Lazada Recall] Failed to recall message #{message.source_id}: #{result.message}"
  end
end
