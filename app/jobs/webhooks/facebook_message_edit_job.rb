# frozen_string_literal: true

class Webhooks::FacebookMessageEditJob < ApplicationJob
  queue_as :low

  def perform(message_edit_json)
    response = ::Integrations::Facebook::MessageEditParser.new(message_edit_json)

    Channel::FacebookPage.where(page_id: response.recipient_id).each do |page|
      Facebook::UpdateMessageService.new(inbox: page.inbox, response: response).perform
    end
  end
end
