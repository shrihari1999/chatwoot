# Returns open conversations that are stranded on an *offline* agent back to the
# auto-assignment pool: it unassigns them and re-kicks the inbox assignment job,
# so an available agent picks them up (or, if none is available, they wait
# unassigned until one comes online — assign-on-online / the periodic sweep).
#
# We deliberately do NOT compute a target ourselves — unassigning and letting the
# existing assignment engine treat them like fresh conversations reuses all of its
# online-filtering / round-robin / capacity logic.
#
# Scope guards:
#   - only inboxes with auto-assignment enabled AND a policy (elsewhere there is no
#     pool to hand back to, so assignment stays sticky — Chatwoot's default);
#   - only *offline* assignees — a busy agent is still present, so they keep theirs.
class AutoAssignment::OfflineReassignmentService
  pattr_initialize [:account!]

  # Safety-net path: every stranded conversation across the account.
  def perform
    return unless enabled?

    reassign(stranded_conversations)
  end

  # Fast path (one-shot): a specific agent who just transitioned to offline.
  def perform_for_agent(user_id)
    return unless enabled?

    reassign(stranded_conversations.where(assignee_id: user_id))
  end

  private

  def enabled?
    account.feature_enabled?('assignment_v2')
  end

  def reassign(scope)
    inbox_ids = []
    scope.find_each do |conversation|
      unassign(conversation)
      inbox_ids << conversation.inbox_id
    end
    # enqueue_for_inbox coalesces per inbox, so one kick per inbox is enough.
    inbox_ids.uniq.each { |inbox_id| AutoAssignment::AssignmentJob.enqueue_for_inbox(inbox_id) }
  end

  def unassign(conversation)
    # Attribute the hand-off to the policy so the activity reads "Automation System".
    # Read from the preloaded inboxes rather than walking conversation.inbox.assignment_policy,
    # which would be two queries per stranded conversation.
    Current.executed_by = eligible_inboxes[conversation.inbox_id]&.assignment_policy
    conversation.update!(assignee: nil)
  ensure
    Current.executed_by = nil
  end

  def stranded_conversations
    # `includes(:inbox)` — Conversation's own update callbacks read `inbox`, so without
    # the preload every unassign is another inbox fetch. find_each preloads per batch.
    scope = account.conversations.open
                   .includes(:inbox)
                   .where(inbox_id: auto_assignment_inbox_ids)
                   .where.not(assignee_id: nil)
    # Exclude present agents (online OR busy). If nobody is present, everyone
    # assigned is stranded, so skip the exclusion rather than emit NOT IN ().
    present = present_agent_ids
    present.any? ? scope.where.not(assignee_id: present) : scope
  end

  def auto_assignment_inbox_ids
    eligible_inboxes.keys
  end

  # Inboxes with auto-assignment on and a policy attached — the only ones where
  # re-pooling actually leads to reassignment. Keyed by id with the policy preloaded,
  # so `unassign` can attribute the hand-off without a per-conversation lookup.
  def eligible_inboxes
    @eligible_inboxes ||= account.inboxes
                                 .where(enable_auto_assignment: true)
                                 .joins(:inbox_assignment_policy)
                                 .includes(:assignment_policy)
                                 .index_by(&:id)
  end

  # Agents with a live heartbeat (online or busy). Anyone not here is offline.
  def present_agent_ids
    OnlineStatusTracker.get_available_users(account.id).keys.map(&:to_i)
  end
end
