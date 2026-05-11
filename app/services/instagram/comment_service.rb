# frozen_string_literal: true

# Handles Instagram `comments` webhook events.  Mirrors how
# Instagram::MessageText coordinates inbound DMs: resolve the inbox,
# ensure the contact exists, then hand the actual message persistence to
# Messages::Instagram::CommentMessageBuilder (which inherits the
# conversation-finding, transaction, idempotency and error-handling
# behaviour from Messages::Instagram::BaseMessageBuilder — same path
# story replies and plain DMs go through).
#
# Webhook value shape (`entry.changes[0].value`):
#   { "id" => "<COMMENT_ID>",
#     "from" => { "id" => "<COMMENTER_IGSID>", "username" => "<USERNAME>" },
#     "media" => { "id" => "<MEDIA_ID>", "media_product_type" => "FEED" },
#     "text" => "<COMMENT_TEXT>",
#     "parent_id" => "<PARENT_COMMENT_ID>"  # optional, only when replying to a comment
#   }
class Instagram::CommentService < Instagram::WebhooksBaseService
  pattr_initialize [:value!, :channel!, :ig_account_id!]

  def perform
    return if commenter_id.blank? || comment_text.blank?
    # Meta also delivers the `comments` webhook when the business itself
    # posts/replies to a comment from the IG app; skip — not an inbound
    # signal from the customer's side.
    return if commenter_id == ig_account_id

    inbox_channel(ig_account_id)
    return if @inbox.blank?
    return if @inbox.channel.reauthorization_required?

    # No profile fetch — commenters often haven't DMed, so the
    # user-profile endpoint errors 230 "User consent required".  The
    # webhook gives us enough (id + username) to bootstrap a contact.
    find_or_create_contact(commenter_user_hash)
    return if @contact_inbox.blank?

    Messages::Instagram::CommentMessageBuilder.new(synthetic_messaging, @inbox).perform
  end

  private

  def commenter_id
    value.dig(:from, :id)
  end

  def commenter_username
    value.dig(:from, :username)
  end

  def comment_text
    value[:text]
  end

  def comment_id
    value[:id]
  end

  def parent_comment_id
    value[:parent_id]
  end

  def media_id
    value.dig(:media, :id)
  end

  def commenter_user_hash
    {
      'id' => commenter_id,
      'name' => commenter_username || "Unknown (IG: #{commenter_id})",
      'username' => commenter_username
    }
  end

  # Shape the comment payload so BaseMessageBuilder can consume it
  # unchanged: it reads sender/recipient/message.mid/message.text and
  # ignores the rest (echoes, attachments, story replies, etc).  We
  # add a top-level :comment key carrying parent_id, media_id and the
  # post's public permalink so the subclass can fold them into
  # content_attributes without re-parsing.
  def synthetic_messaging
    {
      sender: { id: commenter_id },
      recipient: { id: ig_account_id },
      message: { mid: comment_id, text: comment_text },
      comment: { parent_id: parent_comment_id, media_id: media_id, permalink: fetch_post_permalink }
    }.with_indifferent_access
  end

  # Best-effort permalink fetch.  Comment webhook payload doesn't include
  # it; the post's media id needs an additional Graph API lookup.  If the
  # call fails (network, scope) we still create the message — agents
  # just won't get a clickable link.
  def fetch_post_permalink
    return if media_id.blank?

    api_version = GlobalConfigService.load('INSTAGRAM_API_VERSION', 'v22.0')
    response = HTTParty.get(
      "https://graph.instagram.com/#{api_version}/#{media_id}",
      query: { fields: 'permalink', access_token: channel.access_token }
    )
    response.parsed_response.is_a?(Hash) ? response.parsed_response['permalink'] : nil
  rescue StandardError => e
    Rails.logger.warn("Instagram::CommentService permalink fetch failed for media #{media_id}: #{e.message}")
    nil
  end
end
