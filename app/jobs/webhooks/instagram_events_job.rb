class Webhooks::InstagramEventsJob < MutexApplicationJob
  queue_as :default
  # This lock is only a short race dampener for first-message conversation creation.
  # ContactInbox creation is already protected by a unique index, but conversation
  # lookup is `find active conversation || create`, so concurrent first messages from
  # the same IG contact can create duplicate conversations.
  #
  # ActiveJob retries are not FIFO, so a longer retry window does not preserve message
  # order. Use deterministic backoff so the final attempt happens after the 3s lock TTL,
  # then process without the lock instead of dropping the webhook.
  retry_on_lock_conflict wait: ->(executions) { executions.seconds }, attempts: 3, on_exhaustion: :process_without_lock

  # @return [Array] Messaging event keys that are routed to handlers below.
  SUPPORTED_EVENTS = [:message, :read, :reaction, :message_edit].freeze

  def perform(entries)
    @entries = entries

    key = format(::Redis::Alfred::IG_MESSAGE_MUTEX, sender_id: contact_instagram_id, ig_account_id: ig_account_id)
    # Keep the lock TTL just long enough for the first job to fetch profile data and
    # create the contact/conversation. A longer TTL would add user-visible latency for
    # hot contacts without giving us ordering guarantees.
    with_lock(key, 3.seconds) do
      process_entries(entries)
    end
  end

  def process_without_lock(entries)
    Rails.logger.warn("[#{self.class.name}] Processing without lock after lock retry exhaustion")
    process_entries(entries)
  end

  # https://developers.facebook.com/docs/messenger-platform/instagram/features/webhook
  def process_entries(entries)
    entries.each do |entry|
      process_single_entry(entry.with_indifferent_access)
    end
  end

  private

  def process_single_entry(entry)
    # Meta delivers both real comment webhooks AND dev-dashboard "test"
    # events under the same `changes:` payload shape. Distinguish by the
    # `field` value — only "messages" is the dev-dashboard test event.
    # See `.claude/80-meta-webhooks.md`.
    if entry[:changes].present?
      change_field = entry[:changes].first&.dig(:field)
      case change_field
      when 'comments'
        process_comment_event(entry)
      when 'messages'
        process_test_event(entry)
      else
        Rails.logger.info("Instagram Events Job: ignoring unknown changes.field=#{change_field.inspect}")
      end
      return
    end

    process_messages(entry)
  end

  def process_messages(entry)
    messages(entry).each do |messaging|
      Rails.logger.info("Instagram Events Job Messaging: #{messaging}")

      instagram_id = instagram_id(messaging, entry[:id])
      channel = find_channel(instagram_id)

      next if channel.blank?

      if (event_name = event_name(messaging))
        send(event_name, messaging, channel)
      end
    end
  end

  def agent_message_via_echo?(messaging)
    messaging[:message].present? && messaging[:message][:is_echo].present?
  end

  def process_test_event(entry)
    messaging = extract_messaging_from_test_event(entry)

    Instagram::TestEventService.new(messaging).perform if messaging.present?
  end

  def extract_messaging_from_test_event(entry)
    entry[:changes].first&.dig(:value) if entry[:changes].present?
  end

  def process_comment_event(entry)
    value = entry[:changes].first&.dig(:value)
    return if value.blank?

    ig_account_id = entry[:id]
    channel = find_channel(ig_account_id)
    return if channel.blank?

    ::Instagram::CommentService.new(value: value, channel: channel, ig_account_id: ig_account_id).perform
  end

  def instagram_id(messaging, entry_id = ig_account_id)
    if agent_message_via_echo?(messaging)
      messaging.dig(:sender, :id) || entry_id
    else
      # Reaction payloads sometimes omit sender/recipient at the messaging level;
      # fall back to the entry's own Instagram account ID for channel lookup.
      messaging.dig(:recipient, :id) || entry_id
    end
  end

  def ig_account_id
    @entries&.first&.dig(:id)
  end

  def contact_instagram_id
    entry = @entries&.first
    return nil unless entry

    # Handle both messaging and standby arrays
    messaging = (entry[:messaging].presence || entry[:standby] || []).first
    return nil unless messaging

    # For echo messages (outgoing from our account), use recipient's ID (the contact)
    # For incoming messages (from contact), use sender's ID (the contact)
    if messaging.dig(:message, :is_echo)
      messaging.dig(:recipient, :id)
    else
      messaging.dig(:sender, :id)
    end
  end

  def sender_id
    @entries&.dig(0, :messaging, 0, :sender, :id)
  end

  def find_channel(instagram_id)
    # There will be chances for the instagram account to be connected to a facebook page,
    # so we need to check for both instagram and facebook page channels
    # priority is for instagram channel which created via instagram login
    channel = Channel::Instagram.find_by(instagram_id: instagram_id)
    # If not found, fallback to the facebook page channel
    channel ||= Channel::FacebookPage.find_by(instagram_id: instagram_id)

    channel
  end

  def event_name(messaging)
    @event_name ||= SUPPORTED_EVENTS.find { |key| messaging.key?(key) }
  end

  def message(messaging, channel)
    if channel.is_a?(Channel::Instagram)
      ::Instagram::MessageText.new(messaging, channel).perform
    else
      ::Instagram::Messenger::MessageText.new(messaging, channel).perform
    end
  end

  def read(messaging, channel)
    # Use a single service to handle read status for both channel types since the params are same
    ::Instagram::ReadStatusService.new(params: messaging, channel: channel).perform
  end

  def reaction(messaging, channel)
    ::Instagram::MessageReactionService.new(params: messaging, channel: channel).perform
  end

  def message_edit(messaging, channel)
    ::Instagram::UpdateMessageService.new(inbox: channel.inbox, messaging: messaging).perform
  end

  def messages(entry)
    (entry[:messaging].presence || entry[:standby] || [])
  end
end

# Actual response from Instagram webhook (both via Facebook page and Instagram direct)
# [
#   {
#     "time": <timestamp>,
#     "id": <INSTAGRAM_USER_ID>,
#     "messaging": [
#       {
#         "sender": {
#           "id": <INSTAGRAM_USER_ID>
#         },
#         "recipient": {
#           "id": <INSTAGRAM_USER_ID>
#         },
#         "timestamp": <timestamp>,
#         "message": {
#           "mid": <MESSAGE_ID>,
#           "text": <MESSAGE_TEXT>
#         }
#       }
#     ]
#   }
# ]

# Instagram's webhook via Instagram direct testing quirk: Test payloads vs Actual payloads
# When testing in Facebook's developer dashboard, you'll get a Page-style
# payload with a "changes" object. But don't be fooled! Real Instagram DMs
# arrive in the familiar Messenger format with a "messaging" array.
# This apparent inconsistency is actually by design - Instagram's webhooks
# use different formats for testing vs production to maintain compatibility
# with both Instagram Direct and Facebook Page integrations.
# See: https://developers.facebook.com/docs/instagram-platform/webhooks#event-notifications

# Test response from via Instagram direct
# [
#   {
#     "id": "0",
#     "time": <timestamp>,
#     "changes": [
#       {
#         "field": "messages",
#         "value": {
#           "sender": {
#             "id": "12334"
#           },
#           "recipient": {
#             "id": "23245"
#           },
#           "timestamp": "1527459824",
#           "message": {
#             "mid": "random_mid",
#             "text": "random_text"
#           }
#         }
#       }
#     ]
#   }
# ]

# Test response via Facebook page
# [
#   {
#     "time": <timestamp>,,
#     "id": "0",
#     "messaging": [
#       {
#         "sender": {
#           "id": "12334"
#         },
#         "recipient": {
#           "id": "23245"
#         },
#         "timestamp": <timestamp>,
#         "message": {
#             "mid": "random_mid",
#             "text": "random_text"
#         }
#       }
#     ]
#   }
# ]
