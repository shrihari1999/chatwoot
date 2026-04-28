# frozen_string_literal: true

class Instagram::MessageReactionService
  pattr_initialize [:params!, :channel!]

  def perform
    return unless mid && message

    message.apply_reaction!(emoji: emoji, sender_id: sender_id, action: action)
  end

  private

  # Webhooks::InstagramEventsJob symbolizes keys before passing the hash in,
  # so we use symbol access exclusively, matching the surrounding services
  # (Instagram::ReadStatusService, Facebook::MessageReactionService).
  def reaction_data
    @reaction_data ||= params[:reaction] || {}
  end

  def mid
    reaction_data[:mid]
  end

  def emoji
    reaction_data[:emoji]
  end

  def action
    reaction_data[:action]
  end

  def sender_id
    params.dig(:sender, :id)
  end

  def message
    @message ||= channel.inbox.messages.find_by(source_id: mid)
  end
end
