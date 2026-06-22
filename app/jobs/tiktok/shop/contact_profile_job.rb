# Enriches a TikTok Shop contact with the buyer's nickname + avatar.
#
# The new-message webhook only carries the buyer's `im_user_id`, so the contact
# is first created with that id as a placeholder name and no avatar. This job
# fetches the buyer's profile from the Get Conversation Messages API (whose
# message `sender` objects include `nickname` and `avatar`) and backfills it.
#
# Runs in the background so an API failure/rate-limit never affects message
# ingestion. The name is only overwritten while it is still the placeholder, so
# an agent's manual rename is preserved. The avatar is downloaded + stored by
# Avatar::AvatarFromUrlJob (handling the expiring CDN URL).
class Tiktok::Shop::ContactProfileJob < ApplicationJob
  queue_as :default

  def perform(channel_id:, contact_id:, conversation_id:, im_user_id:)
    channel = Channel::TiktokShop.find_by(id: channel_id)
    contact = Contact.find_by(id: contact_id)
    return if channel.nil? || contact.nil?

    profile = fetch_buyer_profile(channel, conversation_id, im_user_id)
    return if profile.blank?

    apply_name(contact, profile[:nickname], im_user_id)
    apply_avatar(contact, profile[:avatar])
  end

  private

  def fetch_buyer_profile(channel, conversation_id, im_user_id)
    # Get Conversation (202601) returns the participant list directly, each with
    # role/nickname/avatar — cleaner than paging through messages.
    response = Tiktok::Shop::Client.new(channel: channel).get_conversation(conversation_id)
    return unless response.success?

    buyer = find_buyer(response.body.dig('data', 'conversation', 'participants'), im_user_id)
    return if buyer.blank?

    { nickname: buyer['nickname'], avatar: buyer['avatar'] }
  end

  # Prefer the participant matching our im_user_id; fall back to any BUYER-role one.
  def find_buyer(participants, im_user_id)
    buyers = Array(participants).select { |p| p['role'] == 'BUYER' }
    buyers.find { |p| p['im_user_id'].to_s == im_user_id.to_s } || buyers.first
  end

  def apply_name(contact, nickname, im_user_id)
    return if nickname.blank?
    # Only replace the placeholder (the raw im_user_id), never an agent's rename.
    return unless contact.name.blank? || contact.name == im_user_id.to_s

    contact.update!(name: nickname)
  end

  def apply_avatar(contact, avatar_url)
    return if avatar_url.blank? || contact.avatar.attached?

    Avatar::AvatarFromUrlJob.perform_later(contact, avatar_url)
  end
end
