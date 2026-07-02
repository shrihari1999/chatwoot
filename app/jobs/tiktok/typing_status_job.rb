# frozen_string_literal: true

class Tiktok::TypingStatusJob < ApplicationJob
  queue_as :default

  def perform(conversation, typing_status)
    Tiktok::TypingStatusService.new(conversation: conversation, typing_status: typing_status).perform
  end
end
