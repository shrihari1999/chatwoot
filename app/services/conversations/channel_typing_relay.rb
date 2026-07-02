# frozen_string_literal: true

# Relays an agent's typing on/off to the customer on channels that support an
# outbound typing indicator, by enqueuing the channel-specific job.
#
# Two rules keep needless work off the queue:
# * Private notes must never leak a typing signal to the customer.
# * START_ONLY_CHANNELS have no "stop" — the provider auto-clears the indicator —
#   so a 'off' event would only enqueue a job that no-ops. We skip it.
class Conversations::ChannelTypingRelay
  pattr_initialize [:conversation!, :typing_status, :is_private]

  # Channels whose provider only supports starting the indicator (LINE Loading
  # Animation, TikTok sender_action=TYPING). Enqueuing on 'off' is wasted work.
  START_ONLY_CHANNELS = %w[Channel::Line Channel::Tiktok].freeze

  def perform
    return if ActiveModel::Type::Boolean.new.cast(is_private)
    return if start_only_channel? && typing_status.to_s != 'on'

    enqueue_job
  end

  private

  def channel_type
    conversation.inbox.channel_type
  end

  def start_only_channel?
    START_ONLY_CHANNELS.include?(channel_type)
  end

  def enqueue_job
    case channel_type
    when 'Channel::FacebookPage'
      # Channel::FacebookPage also backs Instagram DMs, which use a different transport.
      Facebook::TypingStatusJob.perform_later(conversation, typing_status) unless instagram_direct_message?
    when 'Channel::Instagram'
      Instagram::TypingStatusJob.perform_later(conversation, typing_status)
    when 'Channel::Line'
      Line::TypingStatusJob.perform_later(conversation, typing_status)
    when 'Channel::Tiktok'
      Tiktok::TypingStatusJob.perform_later(conversation, typing_status)
    end
  end

  def instagram_direct_message?
    conversation.additional_attributes['type'] == 'instagram_direct_message'
  end
end
