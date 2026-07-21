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
    # There is exactly one open period per agent (enforced by the partial unique
    # index), so the whole set is one query. Looking it up per account_user instead
    # would be an N+1 that runs every single minute.
    open_periods = AgentAvailabilityPeriod.open.index_by { |period| [period.account_id, period.user_id] }

    AccountUser.includes(:account, :user).find_each do |account_user|
      record_status(account_user, open_periods, now)
    rescue StandardError => e
      # Never let one agent's failure abort the whole snapshot.
      Rails.logger.error("AgentAvailabilitySnapshotJob failed for account_user #{account_user.id}: #{e.message}")
    end
  end

  private

  def record_status(account_user, open_periods, now)
    status = account_user.availability_status # 'online' | 'busy' | 'offline'
    open_period = open_periods[[account_user.account_id, account_user.user_id]]

    # Unchanged since last snapshot — the open period already covers it.
    return if open_period&.status == status

    open_period&.update!(ended_at: now)
    AgentAvailabilityPeriod.create!(
      account_id: account_user.account_id,
      user_id: account_user.user_id,
      status: status,
      started_at: now
    )

    act_on_transition(account_user, open_period, status)
  end

  # `previous_period` carries the status the agent just left (nil on the first-ever
  # record, which is not a transition and so triggers nothing):
  #   → online:  assign any conversations that were waiting for someone available.
  #   → offline: hand their conversations back to the pool.
  def act_on_transition(account_user, previous_period, status)
    return if previous_period.nil?

    case status
    when 'online' then trigger_assignment_for(account_user) unless previous_period.online?
    when 'offline' then trigger_offline_handoff_for(account_user) unless previous_period.offline?
    end
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

  # Agent just went offline → return their open conversations to the pool so an
  # available agent picks them up. The 10-min OfflineReassignmentJob is the
  # safety net for anything this one-shot misses.
  def trigger_offline_handoff_for(account_user)
    AutoAssignment::OfflineReassignmentService.new(account: account_user.account)
                                              .perform_for_agent(account_user.user_id)
  end
end
