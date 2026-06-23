# Enriches a Lazada contact with the buyer's profile picture.
#
# The message PUSH carries only account ids + session_id (no avatar). This job
# calls GetSessionDetail (/im/session/get) — the API-sanctioned "synchronize a
# new session" call — whose response includes the buyer's head_url, and hands it
# to Avatar::AvatarFromUrlJob (which downloads + stores it).
#
# Notes:
# - Lazada masks buyer names (title => "T**********r"), so the name is left as-is.
# - Buyers without a custom photo all share one default placeholder image, which
#   we skip so the contact keeps Chatwoot's nicer initial-based avatar.
# - Do NOT swap GetSessionDetail for the session-LIST endpoint: Lazada reclaims
#   API permissions if /im/session/list is polled.
# - Runs in the background so an API failure never affects message ingestion.
class Lazada::ContactProfileJob < ApplicationJob
  queue_as :default

  # Lazada's generic avatar, returned for every buyer who never set a photo.
  DEFAULT_AVATAR_URL = 'https://sg-live.slatic.net/original/ebf238e7aa294b55f5198f2a709efa42.png'.freeze

  def perform(channel_id:, contact_id:, session_id:)
    channel = Channel::Lazada.find_by(id: channel_id)
    contact = Contact.find_by(id: contact_id)
    return if channel.nil? || contact.nil? || contact.avatar.attached?

    avatar_url = fetch_avatar_url(channel, session_id)
    return if avatar_url.blank? || avatar_url == DEFAULT_AVATAR_URL

    Avatar::AvatarFromUrlJob.perform_later(contact, avatar_url)
  end

  private

  def fetch_avatar_url(channel, session_id)
    response = channel.get_session_detail(session_id: session_id)
    return unless response.success?

    response.body.dig('data', 'head_url')
  rescue StandardError => e
    Rails.logger.error("Lazada::ContactProfileJob failed for session_id=#{session_id}: #{e.class}: #{e.message}")
    nil
  end
end
