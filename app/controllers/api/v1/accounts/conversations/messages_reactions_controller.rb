# frozen_string_literal: true

class Api::V1::Accounts::Conversations::MessagesReactionsController < Api::V1::Accounts::Conversations::BaseController
  def create
    emoji  = permitted_params[:emoji]
    action = permitted_params[:reaction_action].presence || 'react'

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
end
