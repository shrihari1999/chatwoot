# frozen_string_literal: true

class Api::V1::Accounts::Conversations::MessagesReactionsController < Api::V1::Accounts::Conversations::BaseController
  def create
    emoji  = permitted_params[:emoji]
    action = permitted_params[:reaction_action].presence || 'react'

    # Best-effort: attempt to forward the reaction to the upstream platform so
    # the customer sees it on their phone.  We always persist the local reaction
    # regardless of whether the platform send succeeds — the Chatwoot UI must
    # update even if the outbound API call fails.
    #
    # Both Facebook Messenger and Instagram support sender_action=react via
    # POST /PAGE-ID/messages (Graph API).
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
  # Both Facebook Messenger and Instagram support sender_action=react.
  def try_send_reaction_to_platform(emoji, action)
    channel = @conversation.inbox.channel
    if channel.is_a?(Channel::Instagram)
      Instagram::SendReactionService.new(message: message, emoji: emoji, action: action).perform
    elsif channel.is_a?(Channel::FacebookPage) && instagram_dm?(channel)
      Instagram::SendReactionService.new(message: message, emoji: emoji, action: action).perform
    elsif channel.is_a?(Channel::FacebookPage)
      Facebook::SendReactionService.new(message: message, emoji: emoji, action: action).perform
    end
  rescue StandardError
    false
  end

  # Returns true when a Channel::FacebookPage inbox is actually used for Instagram
  # Direct Messages.  Chatwoot stores Instagram DM inboxes as Channel::FacebookPage
  # records with instagram_id populated.  Regular Messenger inboxes have a blank
  # instagram_id.
  def instagram_dm?(channel)
    channel.is_a?(Channel::FacebookPage) && channel.instagram_id.present?
  end
end
