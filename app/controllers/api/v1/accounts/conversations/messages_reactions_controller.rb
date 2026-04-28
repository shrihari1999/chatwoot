# frozen_string_literal: true

class Api::V1::Accounts::Conversations::MessagesReactionsController < Api::V1::Accounts::Conversations::BaseController
  def create
    emoji  = permitted_params[:emoji]
    action = permitted_params[:reaction_action].presence || 'react'

    # Best-effort: attempt to forward the reaction to the upstream platform so
    # the customer sees it on their phone.  We always persist the local reaction
    # regardless of whether the platform send succeeds — the Chatwoot UI must
    # update even if the outbound API call fails or the channel doesn't support it.
    #
    # NOTE: Facebook Messenger does NOT expose a reaction API for pages/bots.
    #       Only Instagram supports sender_action=react.
    try_send_reaction_to_platform(emoji, action)

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

  # Attempts to forward the reaction to the upstream platform.
  # Returns true on success, false on failure.  Always safe to call — failures
  # are swallowed so the local reaction is always persisted regardless.
  # Facebook Messenger has no reaction API for pages/bots, so only Instagram is attempted.
  def try_send_reaction_to_platform(emoji, action)
    channel = @conversation.inbox.channel
    return false unless channel.is_a?(Channel::Instagram)

    Instagram::SendReactionService.new(message: message, emoji: emoji, action: action).perform
  rescue StandardError
    false
  end
end
