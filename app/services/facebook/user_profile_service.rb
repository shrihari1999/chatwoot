# Resolves the display name and avatar of a Messenger user from their page-scoped ID.
#
# `GET /{PSID}?fields=first_name,last_name,profile_pic` (the Messenger User Profile API)
# is gated behind Meta's "Business Asset User Profile Access" feature. Until the app is
# granted advanced access for it through App Review, every lookup for a real customer
# fails with code 100 / subcode 33 and the contact lands under FALLBACK_NAME.
#
# Thread participants stay readable with the `pages_messaging` permission the app already
# holds, so we fall back to them for the name. Participants carry no picture, so avatars
# remain unavailable until the feature is approved — at which point the profile lookup
# below starts succeeding again with no further change here.
class Facebook::UserProfileService
  pattr_initialize [:channel!, :source_id!]

  FALLBACK_NAME = 'John Doe'.freeze

  # 2018218: the user has no profile available (privacy settings).
  # 33: the app cannot read the profile — missing "Business Asset User Profile Access".
  EXPECTED_ERROR_SUBCODES = [2_018_218, 33].freeze

  # @return [Hash] name: resolved display name or nil, avatar_url: profile picture or nil
  def perform
    profile = fetch_profile
    name = full_name(profile).presence || fetch_name_from_thread

    # Callers write this straight to contacts.name, which every string column validates at
    # MAX_STRING_COLUMN_LENGTH; an over-long name would fail validation and take the caller's
    # transaction down with it.
    { name: name.presence&.truncate(ApplicationRecord::MAX_STRING_COLUMN_LENGTH, omission: ''), avatar_url: profile['profile_pic'] }
  end

  private

  def api
    @api ||= Koala::Facebook::API.new(channel.page_access_token)
  end

  def full_name(profile)
    [profile['first_name'], profile['last_name']].compact_blank.join(' ')
  end

  def fetch_profile
    api.get_object(source_id) || {}
  rescue Koala::Facebook::AuthenticationError => e
    handle_authentication_error(e)
  rescue Koala::Facebook::ClientError => e
    # Never re-raise: the message this lookup belongs to must still be persisted.
    # An expected error is routine here, so log the message without the backtrace.
    expected_error?(e) ? Rails.logger.warn("Facebook profile unavailable for #{source_id}: #{e.message}") : capture(e)
    {}
  rescue StandardError => e
    capture(e)
    {}
  end

  def fetch_name_from_thread
    threads = api.get_connection(channel.page_id, 'conversations', user_id: source_id, fields: 'participants')
    participants = threads.to_a.first&.dig('participants', 'data') || []
    participants.find { |participant| participant['id'].to_s == source_id.to_s }&.[]('name')
  rescue Koala::Facebook::AuthenticationError => e
    handle_authentication_error(e)
  rescue StandardError => e
    capture(e)
    nil
  end

  def expected_error?(error)
    EXPECTED_ERROR_SUBCODES.include?(error.fb_error_subcode)
  end

  def handle_authentication_error(error)
    Rails.logger.warn("Facebook authentication error for channel: #{channel.id} with error: #{error.message}")
    channel.authorization_error!
    raise
  end

  def capture(error)
    ChatwootExceptionTracker.new(error, account: channel.account).capture_exception
  end
end
