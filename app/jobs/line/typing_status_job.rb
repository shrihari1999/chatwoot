# frozen_string_literal: true

class Line::TypingStatusJob < ApplicationJob
  queue_as :default

  def perform(conversation, typing_status)
    Line::TypingStatusService.new(conversation: conversation, typing_status: typing_status).perform
  end
end
