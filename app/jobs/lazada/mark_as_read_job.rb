# frozen_string_literal: true

class Lazada::MarkAsReadJob < ApplicationJob
  queue_as :default

  def perform(conversation)
    Lazada::MarkAsReadService.new(conversation: conversation).perform
  end
end
