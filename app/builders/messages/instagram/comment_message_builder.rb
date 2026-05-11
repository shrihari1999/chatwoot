# frozen_string_literal: true

# Builds an incoming Chatwoot Message from an Instagram post-comment webhook.
# Reuses Messages::Instagram::BaseMessageBuilder for conversation lookup,
# transaction wrapping, idempotency and error handling — mirroring how
# story replies sit alongside DMs in the same pipeline (both flow through
# BaseMessageBuilder; story replies override only the bits that differ).
#
# The caller (Instagram::CommentService) adapts the `comments` webhook
# payload — which uses an entirely different envelope (`changes[0].value`,
# no `messaging[:sender]`, no `messaging[:message][:mid]`) — into a
# synthetic `messaging` hash shaped like a DM, then hands it to this
# builder.  The synthetic hash adds a top-level `:comment` key carrying
# parent_id and media_id, which this subclass folds into content_attributes.
class Messages::Instagram::CommentMessageBuilder < Messages::Instagram::BaseMessageBuilder
  private

  # Comments come from the commenter; treat as incoming (no echo concept).
  def message_source_id
    @messaging[:sender][:id]
  end

  # Tag the conversation when first created so the UI / reports can tell
  # it apart from a pure-DM thread.  Existing conversations keep whatever
  # type they were created with (typically 'instagram_direct_message').
  def additional_conversation_attributes
    { type: 'instagram_post_comment' }
  end

  # Preserve everything BaseMessageBuilder sets on a message and layer on
  # the comment-specific metadata so future UI work can render comments
  # distinctly without parsing strings out of content.
  def message_params
    params = super
    params[:content_attributes] = (params[:content_attributes] || {}).merge(
      {
        source_type: 'instagram_comment',
        comment_id: @messaging[:message][:mid],
        parent_comment_id: @messaging.dig(:comment, :parent_id),
        post_id: @messaging.dig(:comment, :media_id),
        post_permalink: @messaging.dig(:comment, :permalink)
      }.compact
    )
    params
  end
end
