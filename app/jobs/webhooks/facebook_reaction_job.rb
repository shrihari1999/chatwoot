# frozen_string_literal: true

class Webhooks::FacebookReactionJob < ApplicationJob
  queue_as :low

  def perform(reaction_json)
    parsed = JSON.parse(reaction_json, symbolize_names: true)
    # The gem's Common#to_json wraps the raw messaging hash under a 'messaging' key.
    # Mirror the pattern used by FacebookMessageEditJob/MessageEditParser and accept
    # both shapes for robustness.
    messaging = parsed[:messaging] || parsed
    page_id = messaging.dig(:recipient, :id)
    return if page_id.blank?

    Channel::FacebookPage.where(page_id: page_id).find_each do |page|
      Facebook::MessageReactionService.new(inbox: page.inbox, messaging: messaging).perform
    end
  end
end
