namespace :freshchat do
  desc 'Import historical Freshchat conversations into a Chatwoot inbox. ' \
       'Usage: rails "freshchat:import[<inbox_id>,<channel1|channel2|...>,<dry?>,<limit?>,<since?>]"  ' \
       '(channels separated by "|"; pass "dry" as 3rd arg for dry-run; ' \
       'since="" auto-reads marker, "full" forces full scan, or ISO8601 like 2026-05-27T18:00:00Z)'
  task :import, %i[inbox_id channels mode limit since] => :environment do |_t, args|
    require Rails.root.join('lib/freshchat/importer')

    inbox_id = args[:inbox_id].to_i
    raise ArgumentError, 'inbox_id is required' if inbox_id.zero?

    inbox = Inbox.find(inbox_id)
    channels = args[:channels].to_s.split('|').map(&:strip).reject(&:empty?)
    dry_run = args[:mode].to_s.casecmp('dry').zero?
    limit = args[:limit].present? ? args[:limit].to_i : nil
    since = parse_since(args[:since])

    Freshchat::Importer.new(
      inbox: inbox,
      channels: channels,
      dry_run: dry_run,
      limit: limit,
      since: since
    ).run
  end

  def parse_since(raw)
    str = raw.to_s.strip
    return nil       if str.empty?       # auto: importer reads marker file
    return :full     if str.casecmp('full').zero?

    Time.iso8601(str)
  end
end
