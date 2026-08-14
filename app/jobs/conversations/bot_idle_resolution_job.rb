# Resolves conversations the agent bot is still holding after the customer has gone
# quiet. Freshchat had this built in; Chatwoot's own auto-resolve cannot do it, because
# both `resolvable_*` scopes start from `open` (a bot conversation is `pending`), its
# action is `toggle_status` (which would move a pending conversation to `open`, not
# resolved), and `auto_resolve_after` is a single account-wide number already in use for
# human conversations at a much longer threshold.
class Conversations::BotIdleResolutionJob < ApplicationJob
  queue_as :scheduled_jobs

  IDLE_AFTER = 15.minutes

  def perform
    idle_bot_conversations.each(&:resolved!)
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
end
