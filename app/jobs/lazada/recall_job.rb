# frozen_string_literal: true

class Lazada::RecallJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    Lazada::OutgoingRecallService.new(message: message).perform
  end
end
