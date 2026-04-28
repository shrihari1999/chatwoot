# frozen_string_literal: true

# Builds the Instagram Send-API request body for a reaction.
#
# Instagram accepts:
#   {
#     recipient:     { id: <IGSID> },
#     sender_action: 'react' | 'unreact',
#     payload:       { message_id: <MID> [, reaction: <emoji>] }
#   }
#
# Note: Facebook Messenger does NOT support sender_action=react.
# This builder is used exclusively by Instagram::SendReactionService.
class Messaging::ReactionPayloadBuilder
  REACT_ACTION   = 'react'
  UNREACT_ACTION = 'unreact'
  VALID_ACTIONS  = [REACT_ACTION, UNREACT_ACTION].freeze

  pattr_initialize [:recipient_id!, :message_id!, :emoji, :action!]

  def build
    raise ArgumentError, "Unknown reaction action: #{action}" unless VALID_ACTIONS.include?(action)

    payload = {
      recipient: { id: recipient_id },
      sender_action: action
    }
    payload[:payload] = action == REACT_ACTION ? { message_id: message_id, reaction: emoji } : { message_id: message_id }
    payload
  end
end
