# frozen_string_literal: true

# Relays an agent's typing to the customer on a LINE conversation via LINE's
# Loading Animation API, which shows an animated "loading" indicator in the
# 1:1 chat.
# Ref: https://developers.line.biz/en/docs/messaging-api/use-loading-indicator/
#
# Unlike Messenger/Instagram sender_action=typing_on/typing_off, LINE only offers
# a "start" — the animation auto-dismisses when the next message is sent or after
# loadingSeconds elapses. There is no stop, so we act on typing 'on' only and
# treat 'off' as a no-op.
class Line::TypingStatusService
  pattr_initialize [:conversation!, :typing_status!]

  LOADING_ANIMATION_PATH = '/bot/chat/loading/start'
  # Must be a multiple of 5 between 5 and 60. 20s comfortably bridges the 4s
  # dashboard typing-idle window and a typical compose; the animation clears
  # early when the agent's message is delivered.
  LOADING_SECONDS = 20

  def perform
    return unless line_channel?
    return unless start?
    return if chat_id.blank?

    call_line_api
  end

  private

  def line_channel?
    conversation.inbox.channel_type == 'Channel::Line'
  end

  # The Loading Animation API only starts an animation; there is no stop call.
  def start?
    typing_status.to_s == 'on'
  end

  def channel
    @channel ||= conversation.inbox.channel
  end

  def chat_id
    @chat_id ||= conversation.contact_inbox.source_id
  end

  def call_line_api
    payload = { chatId: chat_id, loadingSeconds: LOADING_SECONDS }.to_json
    response = channel.client.post(channel.client.endpoint, LOADING_ANIMATION_PATH, payload, channel.client.credentials)
    log_failure(response) unless response&.code == '200'
  rescue StandardError => e
    Rails.logger.warn "[Line TypingStatus] Failed to start loading animation for conversation #{conversation.id}: #{e.message}"
  end

  def log_failure(response)
    Rails.logger.warn(
      "[Line TypingStatus] Loading animation request failed for conversation #{conversation.id}: #{response&.code} #{response&.body}"
    )
  end
end
