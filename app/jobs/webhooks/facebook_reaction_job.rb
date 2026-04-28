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
    Rails.logger.info "[ReactionDebug][FacebookReactionJob] page_id=#{page_id.inspect} mid=#{messaging.dig(:reaction, :mid).inspect} action=#{messaging.dig(:reaction, :action).inspect} emoji=#{messaging.dig(:reaction, :emoji).inspect} sender=#{messaging.dig(:sender, :id).inspect}"
    if page_id.blank?
      Rails.logger.warn '[ReactionDebug][FacebookReactionJob] page_id blank, dropping'
      return
    end

    pages = Channel::FacebookPage.where(page_id: page_id)
    Rails.logger.info "[ReactionDebug][FacebookReactionJob] matched #{pages.count} channel(s) for page_id=#{page_id}"
    pages.find_each do |page|
      Facebook::MessageReactionService.new(inbox: page.inbox, messaging: messaging).perform
    end
  end
end
