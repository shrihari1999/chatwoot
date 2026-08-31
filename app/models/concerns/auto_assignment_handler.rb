module AutoAssignmentHandler
  extend ActiveSupport::Concern
  include Events::Types

  included do
    # Legacy (V1) status changes assign inside the same save so status + assignee commit
    # as one change-set (upstream). Bails for assignment_v2 inboxes and for new records.
    before_save :run_legacy_auto_assignment, unless: :new_record?
    # FORK: after_commit, not upstream's after_save. The V2 AssignmentJob queries the
    # inbox's unassigned conversations, so enqueueing from inside the open transaction
    # lets Sidekiq run the scan before this row is committed — the conversation that
    # triggered the job is invisible to it and stays unassigned until the next trigger
    # or periodic sweep. Legacy (before_save) and V2 (after_commit) paths don't overlap:
    # run_legacy bails for v2, and new records only reach run_auto_assignment.
    after_commit :run_auto_assignment, on: %i[create update]
  end

  private

  # Legacy (V1) assignment for status changes runs inside the same save, so status and
  # assignee commit as one change-set; a follow-up save would reset saved_changes and
  # hide the status change from the after_commit callbacks (no conversation.opened).
  def run_legacy_auto_assignment
    return unless status_changed? && open?
    return if inbox.auto_assignment_v2_enabled?
    return unless should_run_auto_assignment?

    AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: legacy_allowed_agent_ids).assign_under_lock
  end

  def run_auto_assignment
    # Assignment V2: Also trigger assignment when conversation is resolved or snoozed,
    # bypassing the open-only condition so the AssignmentJob can redistribute capacity.
    return unless conversation_status_changed_to_open? || conversation_status_changed_to_resolved_or_snoozed?

    # Reopened onto an offline assignee (e.g. the owner is at lunch): the customer is
    # back and waiting, but should_run_auto_assignment? below keeps the conversation
    # sticky because the offline agent is still an inbox member. Hand it back to the
    # pool now instead of waiting up to 10 min for the OfflineReassignmentJob sweep.
    return repool_from_offline_assignee if reopened_onto_offline_assignee?

    return unless should_run_auto_assignment?

    if inbox.auto_assignment_v2_enabled?
      # Coalesces bursts of triggers per inbox; a trigger skipped by the in-flight
      # gate is replayed once by the running job (see AssignmentJob).
      AutoAssignment::AssignmentJob.enqueue_for_inbox(inbox.id)
    elsif saved_change_to_id?
      # Legacy (V1) assignment for new conversations stays post-save: their status is only
      # finalized by before_create callbacks, which run after before_save.
      AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: legacy_allowed_agent_ids).perform
    end
  end

  def legacy_allowed_agent_ids
    # If conversation has a team, only consider team members for assignment
    team_id.present? ? team_member_ids_with_capacity : inbox.member_ids_with_assignment_capacity
  end

  def conversation_status_changed_to_resolved_or_snoozed?
    inbox.auto_assignment_v2_enabled? && saved_change_to_status? && (resolved? || snoozed?)
  end

  # Cheapest checks first so the common reopen (assignee still online) bails on a
  # single Redis read, before any inbox/policy lookup.
  def reopened_onto_offline_assignee?
    # A genuine reopen is an existing conversation returning to open, not a create
    # (create also reports status-changed-to-open). New conversations go through the
    # normal assignment flow above.
    return false if previously_new_record?
    return false unless conversation_status_changed_to_open?
    return false if assignee_id.blank?
    return false unless assignee_offline?
    return false unless inbox.auto_assignment_v2_enabled? && inbox.enable_auto_assignment?

    inbox.assignment_policy.present?
  end

  # Offline = not in the present (online/busy) set — same definition
  # OfflineReassignmentService uses, so a re-pool the handler triggers actually lands.
  def assignee_offline?
    OnlineStatusTracker.get_present_user_ids(account_id).exclude?(assignee_id)
  end

  # Re-pool via the existing service: it unassigns the offline agent's stranded
  # open conversations (now including this one) and re-kicks the inbox so an
  # available agent picks it up. Assignee-only updates don't change status, so the
  # re-entrant run_auto_assignment bails at the first guard — no recursion.
  def repool_from_offline_assignee
    AutoAssignment::OfflineReassignmentService.new(account: account).perform_for_agent(assignee_id)
  end

  def team_member_ids_with_capacity
    return [] if team.blank? || team.allow_auto_assign.blank?

    inbox.member_ids_with_assignment_capacity & team.members.ids
  end

  def should_run_auto_assignment?
    return false unless inbox.enable_auto_assignment?
    # Assignment V2: Resolved/snoozed conversations still have an assignee, so bypass the
    # assignee-blank check below. The AssignmentJob needs to run to rebalance assignments.
    return true if conversation_status_changed_to_resolved_or_snoozed?
    return false if assignee_agent_bot_id.present?

    # run only if assignee is blank or doesn't have access to inbox
    assignee.blank? || inbox.members.exclude?(assignee)
  end
end
