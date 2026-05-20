class Lazada::SendOnLazadaService < Base::SendOnChannelService
  private

  def channel_class
    Channel::Lazada
  end

  def perform_reply
    session_id = conversation.additional_attributes['lazada_session_id']
    return unless session_id

    if message.attachments.present?
      send_attachments(session_id)
    else
      send_text(session_id)
    end
  end

  def send_text(session_id)
    response = channel.send_im_message(
      session_id: session_id,
      template_id: 1,
      txt: message.outgoing_content
    )
    handle_response(response)
  end

  def send_attachments(session_id) # rubocop:disable Metrics/AbcSize
    message.attachments.each_with_index do |attachment, index|
      next unless attachment.file_type == 'image'

      # Use file_url instead of download_url to avoid CORS and authentication issues
      image_url = attachment.file_url

      # Get image dimensions - Lazada requires width and height
      metadata = attachment.file.metadata
      width = metadata['width'] || 800  # Default if not available
      height = metadata['height'] || 600

      Rails.logger.info "[Lazada] Sending image attachment #{index + 1}/#{message.attachments.count} (#{width}x#{height})"

      response = channel.send_im_message(
        session_id: session_id,
        template_id: 3,
        img_url: image_url,
        width: width.to_i,
        height: height.to_i
      )

      handle_response(response, index + 1)
    end

    send_text(session_id) if message.outgoing_content.present?
  end

  def handle_response(response, _attachment_index = nil)
    if response.success?
      message_id = response.body.dig('data', 'message_id')
      message.update!(source_id: message_id) if message_id.present?
      # Update message status to 'sent' after successful delivery
      Messages::StatusUpdateService.new(message, 'sent').perform
    else
      error_msg = response.body&.dig('message') || "Lazada API error: #{response.code}"
      Rails.logger.error "[Lazada] Send failed: #{error_msg}"
      Messages::StatusUpdateService.new(message, 'failed', error_msg).perform
    end
  end
end
