# frozen_string_literal: true

# Builds the Messenger/Instagram Send-API request body for a reaction.
#
# Both Facebook Messenger and Instagram accept:
#   {
#     recipient:     { id: <PSID|IGSID> },
#     sender_action: 'react' | 'unreact',
#     payload:       { message_id: <MID> [, reaction: <emoji>] }
#   }
#
# Used by both Facebook::SendReactionService and Instagram::SendReactionService.
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
