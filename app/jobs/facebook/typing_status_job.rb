# frozen_string_literal: true

class Facebook::TypingStatusJob < ApplicationJob
  queue_as :default

  def perform(conversation, typing_status)
    Facebook::TypingStatusService.new(conversation: conversation, typing_status: typing_status).perform
  end
end
