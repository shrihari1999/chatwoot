# Safety net (every 10 min, see config/schedule.yml): re-pools any open
# conversation still stranded on an offline agent. The AgentAvailabilitySnapshotJob
# one-shot handles this faster (~1 min) on the actual offline transition; this
# catches whatever it misses — conversations manually assigned to an offline agent,
# missed transitions, or agents who were already offline before deploy.
class AutoAssignment::OfflineReassignmentJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform
    Account.find_each do |account|
      next unless account.feature_enabled?('assignment_v2')

      AutoAssignment::OfflineReassignmentService.new(account: account).perform
    rescue StandardError => e
      Rails.logger.error("OfflineReassignmentJob failed for account #{account.id}: #{e.message}")
    end
  end
end
