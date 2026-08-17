class Enterprise::AutoAssignment::CapacityService
  def agent_has_capacity?(user, inbox)
    # Get the account_user for this specific account
    account_user = user.account_users.find_by(account: inbox.account)

    # If no account_user or no capacity policy, agent has unlimited capacity
    return true unless account_user&.agent_capacity_policy

    policy = account_user.agent_capacity_policy

    # Check if there's a specific limit for this inbox
    inbox_limit = policy.inbox_capacity_limits.find_by(inbox: inbox)

    # If no specific limit for this inbox, agent has unlimited capacity for this inbox
    return true unless inbox_limit

    # Fork deviation: the limit caps the agent's total open conversations across the
    # whole account, not just this inbox. Upstream scopes the count to `inbox`, which
    # means an agent can hold `conversation_limit` conversations in every inbox at once
    # (7 inboxes x 20 = 140 here). We want one number that means what it says.
    current_count = user.assigned_conversations
                        .where(account_id: inbox.account_id, status: :open)
                        .count

    # Agent has capacity if current count is below the limit
    current_count < inbox_limit.conversation_limit
  end
end
