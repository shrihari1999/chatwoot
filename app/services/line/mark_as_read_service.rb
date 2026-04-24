# frozen_string_literal: true

# Calls LINE's markAsRead API when an agent views a LINE conversation.
# Uses the markAsReadToken stored on the most recent incoming message.
# Ref: https://developers.line.biz/en/docs/messaging-api/mark-as-read/
class Line::MarkAsReadService
  pattr_initialize [:conversation!]

  MARK_AS_READ_PATH = '/bot/chat/markAsRead'

  def perform
    return unless line_channel?
    return if mark_as_read_token.blank?

    call_line_api
  end

  private

  def line_channel?
    conversation.inbox.channel_type == 'Channel::Line'
  end

  def channel
    @channel ||= conversation.inbox.channel
  end

  def mark_as_read_token
    @mark_as_read_token ||= conversation.messages
                                        .incoming
                                        .where.not("additional_attributes->>'mark_as_read_token' IS NULL")
                                        .order(created_at: :desc)
                                        .pick("additional_attributes->>'mark_as_read_token'")
  end

  def call_line_api
    payload = { markAsReadToken: mark_as_read_token }.to_json
    channel.client.post(channel.client.endpoint, MARK_AS_READ_PATH, payload, channel.client.credentials)
  end
end
