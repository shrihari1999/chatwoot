module Enterprise::ContactInbox
  ANONYMOUS_CALL_SOURCE_ID = /\Aanonymous:CA[0-9a-f]{32}\z/i

  def anonymous_caller?
    # FORK: match source_id first so ordinary conversations never load the inbox (can_reply? runs on every serialization).
    ANONYMOUS_CALL_SOURCE_ID.match?(source_id.to_s) && inbox.channel_type == 'Channel::TwilioSms'
  end

  private

  def validate_twilio_source_id
    return if inbox.channel.voice_enabled? && anonymous_caller?

    super
  end
end
