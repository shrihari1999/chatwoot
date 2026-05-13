class Line::SendOnLineService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Line
  end

  def perform_reply
    response = channel.client.push_message(message.conversation.contact_inbox.source_id, build_payload)

    return if response.blank?

    parsed_json = JSON.parse(response.body)

    if response.code == '200'
      # Persist the LINE-assigned message id and (if any) quoteToken from the `sentMessages`
      # array so that:
      # * Customers quoting this agent message can be matched back via `quotedMessageId` (source_id).
      # * Agents can later quote this message using the stored `quote_token`.
      # See https://developers.line.biz/en/reference/messaging-api/#send-push-message-response
      persist_sent_message_metadata(parsed_json)
      # If the request is successful, update the message status to delivered
      Messages::StatusUpdateService.new(message, 'delivered').perform
    else
      # If the request is not successful, update the message status to failed and save the external error
      Messages::StatusUpdateService.new(message, 'failed', external_error(parsed_json)).perform
    end
  end

  def persist_sent_message_metadata(parsed_json)
    # We send a single text message per outgoing Chatwoot message (attachments are pushed
    # alongside and share the same Chatwoot message). Use the first entry's id/quoteToken.
    first_sent = parsed_json['sentMessages']&.first
    return if first_sent.blank?

    updates = sent_message_updates(first_sent)
    message.update!(updates) if updates.any?
  end

  def sent_message_updates(first_sent)
    updates = {}
    updates[:source_id] = first_sent['id'] if first_sent['id'].present? && message.source_id.blank?

    quote_token = first_sent['quoteToken']
    updates[:additional_attributes] = (message.additional_attributes || {}).merge('quote_token' => quote_token) if quote_token.present?

    updates
  end

  def build_payload
    if message.content_type == 'input_select' && message.content_attributes['items'].any?
      build_input_select_payload
    else
      build_text_payload
    end
  end

  def build_text_payload
    if message.content && message.attachments.any?
      [text_message, *attachments]
    elsif message.content.nil? && message.attachments.any?
      attachments
    else
      text_message
    end
  end

  def attachments
    message.attachments.map do |attachment|
      next unless %w[image video audio].include?(attachment.file_type)

      # Use file_url (permanent redirect-based URL) instead of download_url (signed URL that expires in 5 minutes).
      # LINE mobile app lazy-loads media and may fetch it well after the message is sent.
      original_url = attachment.file_url

      case attachment.file_type
      when 'audio'
        # https://developers.line.biz/en/reference/messaging-api/#audio-message
        # `duration` is required (milliseconds); LINE natively plays m4a only.
        { type: 'audio', originalContentUrl: original_url, duration: audio_duration_ms(attachment) }
      else
        preview_url = attachment.thumb_url.presence || original_url
        { type: attachment.file_type, originalContentUrl: original_url, previewImageUrl: preview_url }
      end
    end
  end

  def audio_duration_ms(attachment)
    blob = attachment.file.blob
    blob.analyze unless blob.analyzed?
    seconds = blob.metadata[:duration] || blob.metadata['duration']
    return (seconds.to_f * 1000).round.clamp(1, nil) if seconds.present?

    Rails.logger.warn("Line::SendOnLineService: audio duration unavailable for attachment #{attachment.id}, defaulting to 1000ms")
    1000
  end

  # https://developers.line.biz/en/reference/messaging-api/#text-message
  def text_message
    { type: 'text', text: message.outgoing_content, quoteToken: quote_token_for_reply }.compact
  end

  # Retrieve the LINE quoteToken for the message being quoted, if any.
  # quoteToken is stored on the quoted message's additional_attributes and is
  # required by LINE to quote a specific message. It expires after 24 hours.
  # Note: LINE only supports quoting user messages (not bot messages).
  def quote_token_for_reply
    quoted_id = message.content_attributes['in_reply_to']
    return if quoted_id.blank?

    message.conversation.messages.find_by(id: quoted_id)&.additional_attributes&.dig('quote_token')
  end

  # https://developers.line.biz/en/reference/messaging-api/#flex-message
  def build_input_select_payload
    {
      type: 'flex',
      altText: message.content,
      contents: {
        type: 'bubble',
        body: {
          type: 'box',
          layout: 'vertical',
          contents: [
            {
              type: 'text',
              text: message.content,
              wrap: true
            },
            *input_select_to_button
          ]
        }
      }
    }
  end

  def input_select_to_button
    message.content_attributes['items'].map do |item|
      {
        type: 'button',
        style: 'link',
        height: 'sm',
        action: {
          type: 'message',
          label: item['title'],
          text: item['value']
        }
      }
    end
  end

  # https://developers.line.biz/en/reference/messaging-api/#error-responses
  def external_error(error)
    # Message containing information about the error. See https://developers.line.biz/en/reference/messaging-api/#error-messages
    message = error['message']
    # An array of error details. If the array is empty, this property will not be included in the response.
    details = error['details']

    return message if details.blank?

    detail_messages = details.map { |detail| "#{detail['property']}: #{detail['message']}" }
    [message, detail_messages].join(', ')
  end
end
