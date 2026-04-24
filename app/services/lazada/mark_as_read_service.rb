# frozen_string_literal: true

# Calls Lazada's /im/session/read API when an agent views a Lazada conversation.
# Uses the lazada_session_id stored on the conversation's additional_attributes.
# Ref: https://open.lazada.com/apps/doc/api?path=%2Fim%2Fsession%2Fread
class Lazada::MarkAsReadService
  pattr_initialize [:conversation!]

  def perform
    return unless lazada_channel?
    return if session_id.blank?

    channel.read_session(session_id: session_id)
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
end
