# frozen_string_literal: true

class Api::V1::Accounts::Conversations::MessagesReactionsController < Api::V1::Accounts::Conversations::BaseController
  def create
    emoji  = permitted_params[:emoji]
    action = permitted_params[:reaction_action].presence || 'react'

    # Send to the upstream platform first; only persist the local reaction if the
    # platform call succeeded (or no upstream send is required for this channel).
    # This keeps the Chatwoot UI in sync with the actual platform state and
    # avoids broadcasting a reaction the customer never received.
    unless send_reaction_to_platform(emoji, action)
      render json: { error: 'Failed to send reaction to platform' }, status: :unprocessable_entity
      return
    end

    message.apply_reaction!(emoji: emoji, sender_id: agent_sender_id, action: action)
    head :ok
  end

  private

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  # The agent_sender_id namespace prevents collisions with raw PSIDs/IGSIDs that
  # are stored verbatim by inbound webhook handlers (see Message#apply_reaction!).
  # An anonymous agent ('agent' with no id) is not idempotent — multiple
  # anonymous reacts will collapse to a single entry — but in practice
  # Current.user is always populated for authenticated API calls.
  def agent_sender_id
    Current.user ? "agent:#{Current.user.id}" : 'agent'
  end

  def permitted_params
    params.permit(:id, :emoji, :reaction_action)
  end

  # Returns true if the platform send succeeded or wasn't required.
  # Returns false (and the controller responds with 422) if the upstream call failed.
  def send_reaction_to_platform(emoji, action)
    channel = @conversation.inbox.channel

    case channel
    when Channel::FacebookPage
      Facebook::SendReactionService.new(message: message, emoji: emoji, action: action).perform
    when Channel::Instagram
      Instagram::SendReactionService.new(message: message, emoji: emoji, action: action).perform
    else
      true
    end
  rescue StandardError
    # ChatwootExceptionTracker has already recorded the upstream error in the
    # send service. We just need to report failure to the caller.
    false
  end
end
