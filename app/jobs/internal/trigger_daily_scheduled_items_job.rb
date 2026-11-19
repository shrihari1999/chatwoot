class Internal::TriggerDailyScheduledItemsJob < ApplicationJob
  queue_as :scheduled_jobs

  # FORK: upstream also schedules Internal::CheckNewVersionsJob (the hub sync) from here.
  # That job overwrites INSTALLATION_PRICING_PLAN and must stay unscheduled, so it is
  # dropped; see .claude/90-enterprise-unlock-recipe.md.
  def perform
    Internal::ExpireDataOperationFilesJob.perform_later
  end
end

Internal::TriggerDailyScheduledItemsJob.prepend_mod_with('Internal::TriggerDailyScheduledItemsJob')
