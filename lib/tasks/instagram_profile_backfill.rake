namespace :instagram do
  desc 'Recover missing social_instagram_* contact attributes from the Instagram User Profile API. ' \
       'Usage: rails "instagram:backfill_profiles[<account_id>,<mode>]"  ' \
       '(account_id optional; mode: "dry" [default] = report only, writes nothing; ' \
       '"commit" = merge the recovered attributes into the contact)'
  task :backfill_profiles, %i[account_id mode] => :environment do |_t, args|
    Instagram::ProfileBackfill.new(
      account_id: args[:account_id],
      mode: args[:mode].presence || 'dry'
    ).run
  end
end
