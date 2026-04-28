# frozen_string_literal: true

class Facebook::MessageReactionService
  pattr_initialize [:inbox!, :messaging!]

  def perform
    Rails.logger.info "[ReactionDebug][MessageReactionService] inbox_id=#{inbox.id} mid=#{mid.inspect} emoji=#{emoji.inspect} action=#{action.inspect} sender_id=#{sender_id.inspect}"
    if mid.nil?
      Rails.logger.warn '[ReactionDebug][MessageReactionService] mid is nil, dropping'
      return
    end
    if message.nil?
      Rails.logger.warn "[ReactionDebug][MessageReactionService] no message found for mid=#{mid} in inbox=#{inbox.id}"
      return
    end

    Rails.logger.info "[ReactionDebug][MessageReactionService] applying reaction to message id=#{message.id} (current reactions=#{message.reactions.inspect})"
    message.apply_reaction!(emoji: emoji, sender_id: sender_id, action: action)
    Rails.logger.info "[ReactionDebug][MessageReactionService] post-apply reactions=#{message.reload.reactions.inspect}"
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
