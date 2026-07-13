# Renames Messenger contacts that were created under the fallback name because the
# Messenger User Profile API refused the lookup (see Facebook::UserProfileService).
# New inbound messages self-heal a contact's name, so this is only needed for contacts
# that may never message again.
#
# Usage:
#   bundle exec rake facebook:backfill_contact_names          # every account
#   bundle exec rake "facebook:backfill_contact_names[2]"     # one account
#   DRY_RUN=true bundle exec rake "facebook:backfill_contact_names[2]"

namespace :facebook do
  desc 'Resolve contacts still named "John Doe" on Facebook inboxes. Args: [account_id]'
  task :backfill_contact_names, [:account_id] => :environment do |_t, args|
    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch('DRY_RUN', false))
    inboxes = Inbox.where(channel_type: 'Channel::FacebookPage')
    inboxes = inboxes.where(account_id: args[:account_id]) if args[:account_id].present?

    inboxes.each do |inbox|
      pending = inbox.contact_inboxes
                     .joins(:contact)
                     .where(contacts: { name: Facebook::UserProfileService::FALLBACK_NAME })
      puts "inbox #{inbox.id} (#{inbox.name}): #{pending.count} contacts under the fallback name"

      resolved = 0
      pending.includes(:contact).find_each do |contact_inbox|
        name = Facebook::UserProfileService.new(channel: inbox.channel, source_id: contact_inbox.source_id).perform[:name]
        next if name.blank? || name == Facebook::UserProfileService::FALLBACK_NAME

        puts "  contact #{contact_inbox.contact_id} (psid #{contact_inbox.source_id}) -> #{name}"
        contact_inbox.contact.update!(name: name) unless dry_run
        resolved += 1
      end

      puts "  #{dry_run ? 'resolvable' : 'resolved'}: #{resolved}"
    end
  end
end
