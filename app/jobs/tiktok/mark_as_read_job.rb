# frozen_string_literal: true

class Tiktok::MarkAsReadJob < ApplicationJob
  queue_as :default

  def perform(conversation)
    Tiktok::MarkAsReadService.new(conversation: conversation).perform
  end
end
