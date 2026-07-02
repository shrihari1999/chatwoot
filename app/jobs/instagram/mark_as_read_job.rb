# frozen_string_literal: true

class Instagram::MarkAsReadJob < ApplicationJob
  queue_as :default

  def perform(conversation)
    Instagram::MarkAsReadService.new(conversation: conversation).perform
  end
end
