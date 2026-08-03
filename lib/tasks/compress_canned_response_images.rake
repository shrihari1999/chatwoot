namespace :canned_responses do
  desc 'Compress oversized canned response images already in storage. ' \
       'Usage: rails "canned_responses:compress_images[<account_id>,<mode>]"  ' \
       '(account_id optional; mode: "dry" [default] = report only, writes nothing; ' \
       '"commit" = repoint attachments at compressed blobs; originals are kept and logged)'
  task :compress_images, %i[account_id mode] => :environment do |_t, args|
    CannedResponses::ImageBackfill.new(
      account_id: args[:account_id],
      mode: args[:mode].presence || 'dry'
    ).run
  end
end
