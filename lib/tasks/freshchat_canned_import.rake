namespace :freshchat do
  desc 'Import Freshchat canned responses (exported markdown) into Chatwoot. ' \
       'Usage: rails "freshchat:canned_import[<account_id>,<file_path>,<mode>]"  ' \
       '(mode: "dry" [default] = report current-vs-planned, writes nothing; ' \
       '"commit" = WIPE all canned responses + categories + image blobs for the account, then rebuild from the file)'
  task :canned_import, %i[account_id file_path mode] => :environment do |_t, args|
    require Rails.root.join('lib/freshchat/canned_importer')

    account_id = args[:account_id].to_i
    raise ArgumentError, 'account_id is required' if account_id.zero?
    raise ArgumentError, 'file_path is required' if args[:file_path].blank?

    Freshchat::CannedImporter.new(
      account_id: account_id,
      file_path: args[:file_path],
      mode: args[:mode].presence || 'dry'
    ).run
  end
end
