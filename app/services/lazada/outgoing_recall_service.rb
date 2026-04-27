# frozen_string_literal: true

# Calls Lazada's /im/message/recall API when an agent deletes a Lazada message
# in Chatwoot. Looks up the message and delegates to the channel's
# recall_im_message helper.
#
# NOTE: A single Chatwoot message can fan out to multiple Lazada messages
# (e.g. one image attachment per send + an optional trailing text). Lazada's
# Send API returns a fresh message_id for every send, and
# Lazada::SendOnLazadaService overwrites `message.source_id` on each
# successful send. As a result `message.source_id` only stores the LAST
# Lazada message id, and only that last fragment is recalled. Recalling the
# earlier fragments of a multi-attachment send is not currently supported.
# Ref: app/services/lazada/send_on_lazada_service.rb#handle_response
class Lazada::OutgoingRecallService
  pattr_initialize [:message!]

  def perform
    return if message.source_id.blank?
    return unless lazada_channel?

    result = channel.recall_im_message(message_id: message.source_id)
    return if result.success?

    Rails.logger.warn "[Lazada Recall] Failed to recall message #{message.source_id}: #{result.message}"
  end

  private

  def channel
    @channel ||= message.inbox.channel
  end

  def lazada_channel?
    message.inbox.channel_type == 'Channel::Lazada'
  end
end
