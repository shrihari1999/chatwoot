# frozen_string_literal: true

# Calls Lazada's /im/session/read API when an agent views a Lazada conversation.
# Uses the lazada_session_id stored on the conversation's additional_attributes.
# Ref: https://open.lazada.com/apps/doc/api?path=%2Fim%2Fsession%2Fread
class Lazada::MarkAsReadService
  pattr_initialize [:conversation!]

  def perform
    return unless lazada_channel?
    return if session_id.blank?
    return if last_read_message_id.blank?

    channel.read_session(session_id: session_id, last_read_message_id: last_read_message_id)
  end

  private

  def lazada_channel?
    conversation.inbox.channel_type == 'Channel::Lazada'
  end

  def channel
    @channel ||= conversation.inbox.channel
  end

  def session_id
    @session_id ||= conversation.additional_attributes&.fetch('lazada_session_id', nil)
  end

  # /im/session/read syncs "the seller has read the buyer's messages", so the last
  # read id is the newest inbound (buyer) message's Lazada message_id (stored as
  # source_id). Marking up to it covers all earlier buyer messages. Blank when the
  # buyer hasn't messaged yet — nothing to mark read, so perform skips the call.
  def last_read_message_id
    @last_read_message_id ||= conversation.messages.incoming
                                          .where.not(source_id: [nil, ''])
                                          .order(:created_at)
                                          .last&.source_id
  end
end
