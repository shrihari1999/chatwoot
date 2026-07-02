# frozen_string_literal: true

class Instagram::TypingStatusJob < ApplicationJob
  queue_as :default

  def perform(conversation, typing_status)
    Instagram::TypingStatusService.new(conversation: conversation, typing_status: typing_status).perform
  end
end
