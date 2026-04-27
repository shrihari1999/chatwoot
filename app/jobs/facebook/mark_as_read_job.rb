# frozen_string_literal: true

class Facebook::MarkAsReadJob < ApplicationJob
  queue_as :default

  def perform(conversation)
    Facebook::MarkAsReadService.new(conversation: conversation).perform
  end
end
