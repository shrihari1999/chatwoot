# frozen_string_literal: true

class Facebook::MessageReactionService
  pattr_initialize [:inbox!, :messaging!]

  def perform
    return unless mid && message

    message.apply_reaction!(emoji: emoji, sender_id: sender_id, action: action)
  end

  private

  def reaction
    @reaction ||= messaging[:reaction] || {}
  end

  def mid
    reaction[:mid]
  end

  def emoji
    reaction[:emoji]
  end

  def action
    reaction[:action]
  end

  def sender_id
    messaging.dig(:sender, :id)
  end

  def message
    @message ||= inbox.messages.find_by(source_id: mid)
  end
end
