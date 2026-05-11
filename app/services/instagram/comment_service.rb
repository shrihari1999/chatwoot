# frozen_string_literal: true

# Handles Instagram `comments` webhook events — a user commented on one of
# the business's posts. We surface each comment as an incoming message in
# a per-contact conversation, alongside the contact's DMs. The agent can
# reply via the existing DM path; replying as a public comment on the post
# itself is a separate, currently-unimplemented endpoint
# (`POST /<COMMENT_ID>/replies`).
#
# Webhook value shape:
#   { "id" => "<COMMENT_ID>",
#     "from" => { "id" => "<COMMENTER_IGSID>", "username" => "<USERNAME>" },
#     "media" => { "id" => "<MEDIA_ID>", "media_product_type" => "FEED" },
#     "text" => "<COMMENT_TEXT>",
#     "parent_id" => "<PARENT_COMMENT_ID>"  # optional, only when reply-to-comment
#   }
class Instagram::CommentService < Instagram::WebhooksBaseService
  pattr_initialize [:value!, :channel!, :ig_account_id!]

  def perform
    return if commenter_id.blank? || comment_text.blank?
    # Echo guard: Meta also delivers a `comments` webhook when the business
    # itself posts a comment from the IG app. Skip — it's not an inbound
    # event from the customer's side.
    return if commenter_id == ig_account_id

    inbox_channel(ig_account_id)
    return if @inbox.blank?
    return if @inbox.channel.reauthorization_required?

    find_or_create_contact(commenter_user_hash)
    return if @contact_inbox.blank?

    return if message_already_exists?

    conversation = find_or_build_conversation
    conversation.messages.create!(message_params(conversation))
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

  # `find_or_create_contact` in WebhooksBaseService expects an `id`/`name`/
  # `username` hash. The comments webhook only carries `from.id` and
  # `from.username`; we don't fetch the IG profile here because comments
  # arrive from people who may have never DMed and thus often error
  # with "User consent is required" (code 230).
  def commenter_user_hash
    {
      'id' => commenter_id,
      'name' => commenter_username || "Unknown (IG: #{commenter_id})",
      'username' => commenter_username
    }
  end

  def find_or_build_conversation
    scope = Conversation.where(account_id: @inbox.account_id, inbox_id: @inbox.id, contact_id: @contact.id)
    if @inbox.lock_to_single_conversation
      scope.order(created_at: :desc).first || build_conversation
    else
      scope.where.not(status: :resolved).order(created_at: :desc).first || build_conversation
    end
  end

  def build_conversation
    Conversation.create!(
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: { type: 'instagram_post_comment' }
    )
  end

  def message_params(conversation)
    {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :incoming,
      status: :sent,
      source_id: comment_id,
      content: comment_text,
      sender: @contact,
      content_attributes: {
        source_type: 'instagram_comment',
        comment_id: comment_id,
        parent_comment_id: parent_comment_id,
        post_id: media_id
      }.compact
    }
  end

  def message_already_exists?
    Message.exists?(inbox_id: @inbox.id, source_id: comment_id)
  end
end
