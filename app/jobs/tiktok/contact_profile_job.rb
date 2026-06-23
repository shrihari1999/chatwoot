# Enriches a TikTok contact with the user's profile picture.
#
# The new-message webhook carries the sender's username + id but no avatar URL.
# This job fetches the conversation's participant list from the Get Messages API
# (/business/message/content/list/), whose `participants[]` entries include a
# temporary `profile_image` URL, and backfills the contact avatar.
#
# Runs in the background so an API failure/rate-limit never affects message
# ingestion. The avatar is downloaded + stored by Avatar::AvatarFromUrlJob
# (handling the expiring CDN URL). The contact name is intentionally left as-is.
class Tiktok::ContactProfileJob < ApplicationJob
  queue_as :default

  def perform(channel_id:, contact_id:, conversation_id:, from_id:)
    channel = Channel::Tiktok.find_by(id: channel_id)
    contact = Contact.find_by(id: contact_id)
    return if channel.nil? || contact.nil? || contact.avatar.attached?

    avatar_url = fetch_avatar_url(channel, conversation_id, from_id)
    return if avatar_url.blank?

    Avatar::AvatarFromUrlJob.perform_later(contact, avatar_url)
  end

  private

  def fetch_avatar_url(channel, conversation_id, from_id)
    client = Tiktok::Client.new(business_id: channel.business_id, access_token: channel.validated_access_token)
    participants = client.list_conversation_messages(conversation_id).dig('data', 'participants')
    find_personal_account(participants, from_id)&.[]('profile_image')
  rescue StandardError => e
    Rails.logger.error(
      "Tiktok::ContactProfileJob failed for conversation_id=#{conversation_id}, " \
      "business_id=#{channel.business_id}: #{e.class}: #{e.message}"
    )
    nil
  end

  # Prefer the participant matching the sender id; fall back to any personal account.
  def find_personal_account(participants, from_id)
    personal = Array(participants).select { |p| p['role'] == 'PERSONAL_ACCOUNT' }
    personal.find { |p| p['id'].to_s == from_id.to_s } || personal.first
  end
end
