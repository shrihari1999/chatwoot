# frozen_string_literal: true

module Facebook
  class MessageReactionService
    def initialize(inbox:, messaging:)
      @inbox    = inbox
      @messaging = messaging
    end

    def perform
      mid       = @messaging.dig(:reaction, :mid)
      emoji     = @messaging.dig(:reaction, :emoji)
      action    = @messaging.dig(:reaction, :action)
      sender_id = @messaging.dig(:sender, :id)

      message = @inbox.messages.find_by(source_id: mid)
      return unless message

      message.apply_reaction!(emoji: emoji, sender_id: sender_id, action: action)
    end
  end
end
