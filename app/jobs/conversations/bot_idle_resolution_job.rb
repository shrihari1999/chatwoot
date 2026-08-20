# Clears out conversations the agent bot is still holding after the customer has gone
# quiet: the bot answered and nobody came back, so the conversation is resolved. Freshchat
# had this built in; Chatwoot's own auto-resolve cannot do it, because both `resolvable_*`
# scopes start from `open` (a bot conversation is `pending`), its action is `toggle_status`
# (which would move a pending conversation to `open`, not resolved), and `auto_resolve_after`
# is a single account-wide number already in use for human conversations at a much longer
# threshold.
class Conversations::BotIdleResolutionJob < ApplicationJob
  queue_as :scheduled_jobs

  IDLE_AFTER = 15.minutes

  def perform
    idle_bot_conversations.each do |conversation|
      # The customer wrote last and nothing answered them — the bot ignored the message
      # (caption-less photos never reach its text pipeline) or dropped it. Resolving buries
      # the question where no agent will ever see it, so hand the conversation to a human
      # instead: `bot_handoff!` clears the bot and opens the conversation, which is what the
      # assignment sweep needs before it can route it to an agent.
      awaiting_reply?(conversation) ? conversation.bot_handoff! : conversation.resolved!
    end
  end

  private

  # `pending` + an agent bot assignee is precisely "the bot still owns this". A handoff
  # calls `bot_handoff!`, which nils the bot and opens the conversation, and assigning a
  # human nils it via `reset_agent_bot_when_assignee_present` — so both drop out here
  # without needing an explicit exclusion.
  def idle_bot_conversations
    Conversation.pending
                .where.not(assignee_agent_bot_id: nil)
                .where(last_activity_at: ...IDLE_AFTER.ago)
                .limit(Limits::BULK_ACTIONS_LIMIT)
  end

  # Only incoming and outgoing count. Activity messages are bookkeeping — an SLA policy is
  # attached a second after every first customer message, so counting those would make every
  # conversation look answered — and templates are automated outbound, not a reply.
  def awaiting_reply?(conversation)
    conversation.messages.where(message_type: [:incoming, :outgoing]).order(:id).last&.incoming?
  end
end
