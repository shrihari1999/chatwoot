# frozen_string_literal: true

class Webhooks::FacebookReactionJob < ApplicationJob
  queue_as :low

  def perform(reaction_json)
    messaging = JSON.parse(reaction_json, symbolize_names: true)
    page_id = messaging.dig(:recipient, :id)

    Channel::FacebookPage.where(page_id: page_id).each do |page|
      Facebook::MessageReactionService.new(inbox: page.inbox, messaging: messaging).perform
    end
  end
end
