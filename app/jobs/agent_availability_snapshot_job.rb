# Runs once a minute (see config/schedule.yml). For every agent it reads the
# effective availability the exact same way auto-assignment does
# (AvailabilityStatusable#availability_status, which honours auto_offline + the
# live Redis heartbeat) and edge-logs transitions into agent_availability_periods:
# a new row is written only when an agent's status changes, so the table stays
# small and reads back as clean intervals.
#
# It also serves as the "assign on agent online" fast path: when an agent
# transitions *to* online, it kicks the inbox assignment job for each inbox they
# belong to, so a conversation that was waiting because nobody was available gets
# picked up within ~1 min instead of waiting for the 10-min periodic sweep (which
# still runs as the safety net).
class AgentAvailabilitySnapshotJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    now = Time.current
    AccountUser.includes(:account, :user).find_each do |account_user|
      record_status(account_user, now)
    rescue StandardError => e
      # Never let one agent's failure abort the whole snapshot.
      Rails.logger.error("AgentAvailabilitySnapshotJob failed for account_user #{account_user.id}: #{e.message}")
    end
  end

  private

  def record_status(account_user, now)
    status = account_user.availability_status # 'online' | 'busy' | 'offline'
    open_period = AgentAvailabilityPeriod.open.find_by(
      account_id: account_user.account_id, user_id: account_user.user_id
    )

    # Unchanged since last snapshot — the open period already covers it.
    return if open_period&.status == status

    # A known non-online period is now closing into 'online' → the agent just
    # became available. (First-ever record isn't a transition, so it's skipped.)
    became_available = status == 'online' && open_period.present? && !open_period.online?

    open_period&.update!(ended_at: now)
    AgentAvailabilityPeriod.create!(
      account_id: account_user.account_id,
      user_id: account_user.user_id,
      status: status,
      started_at: now
    )

    trigger_assignment_for(account_user) if became_available
  end

  # Kick a bulk-assignment pass for every inbox this agent is a member of.
  # enqueue_for_inbox coalesces per inbox, and the job no-ops for inboxes without
  # auto-assignment/a policy, so this is cheap and safe to fire broadly.
  def trigger_assignment_for(account_user)
    Inbox.where(account_id: account_user.account_id)
         .joins(:inbox_members)
         .where(inbox_members: { user_id: account_user.user_id })
         .distinct
         .pluck(:id)
         .each { |inbox_id| AutoAssignment::AssignmentJob.enqueue_for_inbox(inbox_id) }
  end
end
