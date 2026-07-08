# Reports on the durable agent-availability history recorded by
# AgentAvailabilitySnapshotJob into agent_availability_periods.
#
# Usage:
#   # Per-agent timeline for a day (default: today, Asia/Bangkok):
#   bundle exec rake "agent_availability:report[3]"
#   bundle exec rake "agent_availability:report[3,2026-07-08,Asia/Bangkok]"
#
#   # Who was online/busy/offline at a given instant (answers "was anyone
#   # available at 12:46?"):
#   bundle exec rake "agent_availability:at[2,2026-07-08 12:46,Asia/Bangkok]"

# rubocop:disable Metrics/BlockLength
namespace :agent_availability do
  desc 'Availability timeline + totals for one agent on a day. Args: user_id[,YYYY-MM-DD][,TZ]'
  task :report, %i[user_id date tz] => :environment do |_t, args|
    abort 'user_id is required' if args[:user_id].blank?
    tz = args[:tz].presence || 'Asia/Bangkok'

    Time.use_zone(tz) do
      date = args[:date].present? ? Time.zone.parse(args[:date]).to_date : Time.zone.today
      day_start = date.beginning_of_day
      day_end = date.end_of_day
      user = User.find(args[:user_id])

      periods = AgentAvailabilityPeriod.where(user_id: user.id)
                                       .overlapping(day_start, day_end)
                                       .order(:started_at)

      puts "Agent #{user.name} (id #{user.id}) — #{date} (#{tz})"
      if periods.empty?
        puts '  (no availability recorded for this day)'
        next
      end

      totals = Hash.new(0)
      periods.each do |period|
        from = [period.started_at.in_time_zone, day_start].max
        to = [(period.ended_at&.in_time_zone || Time.zone.now), day_end].min
        secs = (to - from).to_i
        next if secs <= 0

        totals[period.status] += secs
        marker = period.ended_at.nil? ? ' (ongoing)' : ''
        puts "  #{period.status.ljust(8)} #{from.strftime('%H:%M')} – #{to.strftime('%H:%M')}  (#{humanize_duration(secs)})#{marker}"
      end

      stints = periods.count { |p| p.offline? && (p.ended_at&.in_time_zone || Time.zone.now) > day_start }
      puts "  #{'-' * 40}"
      puts "  Available (online): #{humanize_duration(totals['online'])} · " \
           "Busy: #{humanize_duration(totals['busy'])} · " \
           "Offline: #{humanize_duration(totals['offline'])} · Offline stints: #{stints}"
    end
  end

  desc 'Effective availability of every agent at an instant. Args: account_id,"YYYY-MM-DD HH:MM"[,TZ]'
  task :at, %i[account_id at tz] => :environment do |_t, args|
    abort 'account_id and time are required' if args[:account_id].blank? || args[:at].blank?
    tz = args[:tz].presence || 'Asia/Bangkok'

    Time.use_zone(tz) do
      at = Time.zone.parse(args[:at])
      account = Account.find(args[:account_id])
      puts "Availability at #{at.strftime('%Y-%m-%d %H:%M')} (#{tz}) — account #{account.id}"

      account.account_users.includes(:user).sort_by { |au| au.user.name.to_s }.each do |au|
        period = AgentAvailabilityPeriod.where(account_id: account.id, user_id: au.user_id)
                                        .where('started_at <= ? AND (ended_at IS NULL OR ended_at > ?)', at, at)
                                        .order(started_at: :desc).first
        status = period&.status || 'unknown (no record)'
        puts "  #{au.user.name.to_s.ljust(24)} #{status}"
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength

def humanize_duration(seconds)
  hours = seconds / 3600
  minutes = (seconds % 3600) / 60
  hours.positive? ? "#{hours}h#{minutes.to_s.rjust(2, '0')}m" : "#{minutes}m"
end
