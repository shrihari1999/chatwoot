# frozen_string_literal: true

module Facebook
  class SendReactionService
    def initialize(message:, emoji:, action: 'react')
      @message = message
      @emoji   = emoji
      @action  = action
    end

    def perform
      return unless psid.present? && mid.present?

      payload = {
        recipient:     { id: psid },
        sender_action: @action
      }

      if @action == 'react'
        payload[:payload] = { message_id: mid, reaction: @emoji }
      else
        payload[:payload] = { message_id: mid }
      end

      Facebook::Messenger::Bot.deliver(payload, page_id: channel.page_id)
    rescue Facebook::Messenger::FacebookError => e
      Rails.logger.warn "[Facebook::SendReactionService] Failed for message #{@message.id}: #{e.message}"
    end

    private

    def channel
      @channel ||= @message.conversation.inbox.channel
    end

    def psid
      @psid ||= @message.conversation.contact.get_source_id(@message.conversation.inbox_id)
    end

    def mid
      @mid ||= @message.source_id
    end
  end
end
