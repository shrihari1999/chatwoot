# frozen_string_literal: true

module Instagram
  class SendReactionService
    def initialize(message:, emoji:, action: 'react')
      @message = message
      @emoji   = emoji
      @action  = action
    end

    def perform
      return unless igsid.present? && mid.present?

      body = {
        recipient:     { id: igsid },
        sender_action: @action
      }

      if @action == 'react'
        body[:payload] = { message_id: mid, reaction: @emoji }
      else
        body[:payload] = { message_id: mid }
      end

      api_version  = GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v22.0')
      instagram_id = channel.instagram_id.presence || 'me'
      access_token = channel.access_token

      response = HTTParty.post(
        "https://graph.instagram.com/#{api_version}/#{instagram_id}/messages",
        body: body,
        query: { access_token: access_token }
      )

      unless response.success?
        Rails.logger.warn "[Instagram::SendReactionService] Failed for message #{@message.id}: #{response.parsed_response}"
      end
    rescue StandardError => e
      Rails.logger.warn "[Instagram::SendReactionService] Error for message #{@message.id}: #{e.message}"
    end

    private

    def channel
      @channel ||= @message.conversation.inbox.channel
    end

    def igsid
      @igsid ||= @message.conversation.contact.get_source_id(@message.conversation.inbox_id)
    end

    def mid
      @mid ||= @message.source_id
    end
  end
end
