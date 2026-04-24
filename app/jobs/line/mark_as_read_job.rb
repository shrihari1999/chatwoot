# frozen_string_literal: true

class Line::MarkAsReadJob < ApplicationJob
  queue_as :default

  def perform(conversation)
    Line::MarkAsReadService.new(conversation: conversation).perform
  end
end
