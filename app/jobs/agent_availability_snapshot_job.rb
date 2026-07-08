# Runs once a minute (see config/schedule.yml). For every agent it reads the
# effective availability the exact same way auto-assignment does
# (AvailabilityStatusable#availability_status, which honours auto_offline + the
# live Redis heartbeat) and edge-logs transitions into agent_availability_periods:
# a new row is written only when an agent's status changes, so the table stays
# small and reads back as clean intervals.
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

    open_period&.update!(ended_at: now)
    AgentAvailabilityPeriod.create!(
      account_id: account_user.account_id,
      user_id: account_user.user_id,
      status: status,
      started_at: now
    )
  end
end
