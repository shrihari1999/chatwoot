# frozen_string_literal: true

class Api::V1::Accounts::Conversations::MessagesReactionsController < Api::V1::Accounts::Conversations::BaseController
  def create
    emoji  = permitted_params[:emoji]
    action = permitted_params[:reaction_action].presence || 'react'

    message.apply_reaction!(emoji: emoji, sender_id: agent_sender_id, action: action)
    send_reaction_to_platform(emoji, action)

    head :ok
  end

  private

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def agent_sender_id
    Current.user ? "agent:#{Current.user.id}" : 'agent'
  end

  def permitted_params
    params.permit(:id, :emoji, :reaction_action)
  end

  def send_reaction_to_platform(emoji, action)
    channel = @conversation.inbox.channel

    case channel
    when Channel::FacebookPage
      Facebook::SendReactionService.new(message: message, emoji: emoji, action: action).perform
    when Channel::Instagram
      Instagram::SendReactionService.new(message: message, emoji: emoji, action: action).perform
    end
  end
end
