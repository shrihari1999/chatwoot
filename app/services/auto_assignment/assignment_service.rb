class AutoAssignment::AssignmentService
  pattr_initialize [:inbox!]

  def perform_bulk_assignment(limit: 100)
    return 0 unless inbox.auto_assignment_v2_enabled?
    return 0 unless inbox.enable_auto_assignment?

    conversations = unassigned_conversations(limit).to_a
    return 0 if conversations.empty?
    return 0 if inbox.available_agents.empty?

    assigned_count = 0
    conversations.each do |conversation|
      assigned_count += 1 if perform_for_conversation(conversation)
    end
    assigned_count
  end

  private

  def perform_for_conversation(conversation)
    return false unless assignable?(conversation)

    agent = find_available_agent(conversation)
    return false unless agent

    assign_conversation(conversation, agent)
  end

  def assignable?(conversation)
    conversation.status == 'open' &&
      conversation.assignee_id.nil?
  end

  def unassigned_conversations(limit)
    scope = inbox.conversations.unassigned.open

    # Skip stale backlog with no activity beyond the age threshold
    policy = inbox.assignment_policy
    scope = apply_age_exclusions(scope, age_exclusion_hours(policy))

    # Apply conversation priority using assignment policy if available
    scope = if policy&.longest_waiting?
              scope.reorder(last_activity_at: :asc, created_at: :asc)
            else
              scope.reorder(created_at: :asc)
            end

    scope.limit(limit)
  end

  def age_exclusion_hours(policy)
    return policy.exclude_older_than_hours if policy

    AssignmentPolicy::DEFAULT_EXCLUDE_OLDER_THAN_HOURS
  end

  def apply_age_exclusions(scope, hours_threshold)
    return scope if hours_threshold.blank?

    hours = hours_threshold.to_i
    return scope unless hours.positive?

    # Use last_activity_at so reopened/active conversations aren't excluded by their original created_at
    scope.where('conversations.last_activity_at >= ?', hours.hours.ago)
  end

  def find_available_agent(conversation = nil)
    agents = filter_agents_by_team(inbox.available_agents, conversation)
    return nil if agents.nil?

    agents = filter_agents_by_rate_limit(agents)
    return nil if agents.empty?

    round_robin_selector.select_agent(agents)
  end

  def filter_agents_by_team(agents, conversation)
    return agents if conversation&.team_id.blank?

    team = conversation.team
    return nil if team.blank? || team.allow_auto_assign.blank?

    team_member_ids = team.members.ids
    agents.where(user_id: team_member_ids)
  end

  def filter_agents_by_rate_limit(agents)
    agents.select do |agent_member|
      rate_limiter = build_rate_limiter(agent_member.user)
      rate_limiter.within_limit?
    end
  end

  def assign_conversation(conversation, agent)
    return false unless claim_and_assign(conversation, agent)

    conversation.reload

    rate_limiter = build_rate_limiter(agent)
    rate_limiter.track_assignment(conversation)

    # NOTE: no explicit ASSIGNEE_CHANGED dispatch here on purpose -- see the comment
    # above `claim_and_assign`.
    true
  end

  # FORK DEVIATION from upstream v4.16.2 -- do not reinstate on sync without reading this.
  #
  # Upstream's `assign_conversation` called a `dispatch_assignment_event` helper here that
  # dispatched ASSIGNEE_CHANGED explicitly. That made every successful auto-assignment
  # dispatch the event TWICE, because `locked.update!(assignee: agent)` below already
  # triggers `Conversation`'s `after_commit :notify_assignment_change`
  # (app/models/concerns/assignment_handler.rb). Both dispatches reach the same four
  # async listeners, so ParticipationListener ran twice and its `find_or_create_by!`
  # raced itself -- ~470 unique-constraint violations/day on conversation_participants,
  # 93% of all our Postgres ERROR lines. Harmless to users (the listener rescues
  # RecordNotUnique) but it doubled the listener work on every assignment.
  #
  # The removed dispatch was also strictly poorer than the callback one. It sent only
  # {conversation, user}; the callback sends {conversation, notifiable_assignee_change,
  # changed_attributes, performed_by}. Note `performed_by` in particular: it reads
  # Current.executed_by, which is still set when the after_commit fires (the `ensure`
  # below runs after the transaction commits) but nil by the time the explicit dispatch
  # ran. No assignee_changed listener reads `user`, so nothing depended on it.
  #
  # Upstream history: #9334 (2024-05-06) fixed the callback not firing; #9449 (2024-05-10)
  # added the rescue that hid the race; #12320 (2025-11-17, Assignment v2) introduced the
  # redundant dispatch. Reported upstream -- drop this deviation once they fix it.
  #
  # DEPENDENCY: this relies on the after_commit callback continuing to fire. The
  # "dispatches assignee changed event exactly once" spec guards that; if it ever starts
  # asserting zero dispatches, the callback broke -- fix that, don't re-add this helper.
  #
  # Atomically claim the row so two bulk runs that overlap (the in-flight gate
  # is best-effort and can lapse on TTL) can't both assign the same conversation.
  def claim_and_assign(conversation, agent)
    Current.executed_by = inbox.assignment_policy || inbox

    Conversation.transaction do
      locked = inbox.conversations
                    .where(id: conversation.id, assignee_id: nil)
                    .lock('FOR UPDATE SKIP LOCKED')
                    .first
      next false unless locked

      locked.update!(assignee: agent)
      true
    end
  ensure
    Current.executed_by = nil
  end

  def build_rate_limiter(agent)
    AutoAssignment::RateLimiter.new(inbox: inbox, agent: agent)
  end

  def round_robin_selector
    @round_robin_selector ||= AutoAssignment::RoundRobinSelector.new(inbox: inbox)
  end
end

AutoAssignment::AssignmentService.prepend_mod_with('AutoAssignment::AssignmentService')
