require 'rails_helper'

# FORK: upstream's version of this job also schedules Internal::CheckNewVersionsJob (the hub
# sync that overwrites INSTALLATION_PRICING_PLAN). The fork drops that, so this spec guards it.
RSpec.describe Internal::TriggerDailyScheduledItemsJob do
  before do
    allow(Captain::Documents::ScheduleSyncsJob).to receive(:perform_later)
  end

  it 'enqueues the job' do
    expect { described_class.perform_later }.to have_enqueued_job(described_class)
      .on_queue('scheduled_jobs')
  end

  it 'enqueues the data operation file cleanup' do
    expect { described_class.perform_now }.to have_enqueued_job(Internal::ExpireDataOperationFilesJob)
  end

  it 'never schedules the hub version check, even in production' do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(Internal::CheckNewVersionsJob).to receive(:set)
    allow(Internal::CheckNewVersionsJob).to receive(:perform_later)

    expect { described_class.perform_now }.not_to have_enqueued_job(Internal::CheckNewVersionsJob)
    expect(Internal::CheckNewVersionsJob).not_to have_received(:set)
    expect(Internal::CheckNewVersionsJob).not_to have_received(:perform_later)
  end
end
