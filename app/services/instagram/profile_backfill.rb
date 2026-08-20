# Recovers the `social_instagram_*` attributes for Instagram contacts whose ContactInbox
# was created without a successful User Profile API lookup. Instagram::BaseMessageText
# only fetches a profile on a contact's *first* message (`contacts_first_message?`), so
# once the ContactInbox exists these contacts never retry on their own.
#
# Only contacts whose `source_id` is a real Instagram-scoped ID (numeric) can be resolved.
# Contacts imported from Freshchat carry a `freshchat-customer-…` source_id and have no
# IGSID to look up; those self-heal instead, because their next inbound DM arrives under a
# real IGSID that Instagram::WebhooksBaseService's handle-dedup path links to the contact.
#
# Expect most lookups to fail with error 230 ("User consent is required to access user
# profile"). Consent is a permanent per-user property, not a decaying one, so those
# contacts are not recoverable through this API.
class Instagram::ProfileBackfill
  REQUEST_FIELDS = %w[name username follower_count is_user_follow_business is_business_follow_user is_verified_user].freeze
  STORED_FIELDS = %w[follower_count is_user_follow_business is_business_follow_user is_verified_user].freeze
  THROTTLE_SECONDS = 0.2

  def initialize(account_id: nil, mode: 'dry')
    @account_id = account_id.presence
    @commit = mode.to_s == 'commit'
  end

  def run
    log @commit ? 'Mode: COMMIT (recovered attributes will be written)' : 'Mode: DRY RUN (nothing is written)'
    log "Scope: #{@account_id ? "account #{@account_id}" : 'all accounts'}"
    inboxes.each { |inbox| backfill(inbox) }
  end

  private

  def inboxes
    scope = Inbox.where(channel_type: 'Channel::Instagram')
    return scope if @account_id.blank?

    scope.where(account_id: @account_id)
  end

  def backfill(inbox)
    @access_token = inbox.channel.access_token
    @tally = Hash.new(0)
    @samples = {}

    scope = pending(inbox)
    log "inbox #{inbox.id} (#{inbox.name}): #{scope.count} contacts with a resolvable IGSID and no profile data"
    scope.includes(:contact).find_each { |contact_inbox| process(contact_inbox) }
    print_summary
  end

  # A numeric source_id is an Instagram-scoped ID; anything else (e.g. `freshchat-customer-…`)
  # has no IGSID and can never resolve, so it is excluded rather than burned on a doomed call.
  def pending(inbox)
    inbox.contact_inboxes
         .joins(:contact)
         .where("contact_inboxes.source_id ~ '^[0-9]+$'")
         .where("NOT (contacts.additional_attributes ? 'social_instagram_follower_count')")
  end

  def process(contact_inbox)
    profile = fetch(contact_inbox.source_id)
    return if profile.nil?

    recovered = profile.slice(*STORED_FIELDS)
    return @tally['no profile fields returned'] += 1 if recovered.empty?

    attributes = recovered.transform_keys { |field| "social_instagram_#{field}" }
    contact = contact_inbox.contact
    log "  contact #{contact.id} (@#{profile['username']}) -> #{attributes.inspect}"
    contact.update!(additional_attributes: contact.additional_attributes.merge(attributes)) if @commit
    @tally[@commit ? 'recovered' : 'recoverable'] += 1
  end

  def fetch(source_id)
    response = HTTParty.get("#{base_uri}/#{source_id}?fields=#{REQUEST_FIELDS.join(',')}&access_token=#{@access_token}")
    sleep THROTTLE_SECONDS

    parsed = response.parsed_response
    parsed = JSON.parse(parsed) if parsed.is_a?(String)
    return parsed if response.success?

    label = "error #{parsed.dig('error', 'code')}"
    @tally[label] += 1
    @samples[label] ||= parsed.dig('error', 'message')
    nil
  end

  def base_uri
    "https://graph.instagram.com/#{GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v22.0')}"
  end

  def print_summary
    @tally.sort_by { |_, count| -count }.each do |label, count|
      log "  #{count.to_s.rjust(5)}  #{label}#{@samples[label] ? " — #{@samples[label]}" : ''}"
    end
    log "\n(DRY RUN — re-run with mode=commit to apply.)" unless @commit
  end

  # This is a rake-invoked reporter; stdout is the point.
  def log(message)
    puts message # rubocop:disable Rails/Output
  end
end
