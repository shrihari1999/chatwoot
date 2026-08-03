namespace :canned_responses do
  desc 'Pre-generate preview variants for canned response images. ' \
       'Usage: rails "canned_responses:generate_thumbnails[<account_id>]" (account_id optional). ' \
       'Run after deploying so the first picker open does not build variants inline.'
  task :generate_thumbnails, [:account_id] => :environment do |_t, args|
    CannedResponses::ThumbnailGenerator.new(account_id: args[:account_id]).run
  end
end
