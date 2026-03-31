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

  def send_attachments(session_id)
    Rails.logger.info "[Lazada SendAttachment] Sending #{message.attachments.count} attachments for message #{message.id}"
    
    message.attachments.each_with_index do |attachment, index|
      next unless attachment.file_type == 'image'

      # Use file_url instead of download_url to avoid CORS and authentication issues
      # file_url goes through Chatwoot's server which can be accessed by Lazada
      image_url = attachment.file_url
      
      Rails.logger.info "[Lazada SendAttachment] Sending attachment #{index + 1}/#{message.attachments.count}: #{attachment.file.filename}"
      Rails.logger.info "[Lazada SendAttachment] Image URL: #{image_url}"
      
      response = channel.send_im_message(
        session_id: session_id,
        template_id: 3,
        img_url: image_url
      )
      
      Rails.logger.info "[Lazada SendAttachment] Attachment #{index + 1} response: success=#{response.success?}, body=#{response.body}"
      
      handle_response(response, index)
    end

    send_text(session_id) if message.outgoing_content.present?
  end

  def handle_response(response, attachment_index = nil)
    prefix = attachment_index ? "[Attachment #{attachment_index}]" : ""
    
    if response.success?
      message_id = response.body.dig('data', 'message_id')
      
      Rails.logger.info "[Lazada SendMessage] #{prefix} Success! message_id: #{message_id}"
      
      message.update!(source_id: message_id) if message_id.present?
      # Update message status to 'sent' after successful delivery
      Messages::StatusUpdateService.new(message, 'sent').perform
    else
      error_msg = response.body&.dig('message') || "Lazada API error: #{response.code}"
      
      Rails.logger.error "[Lazada SendMessage] #{prefix} Failed! Error: #{error_msg}"
      
      Messages::StatusUpdateService.new(message, 'failed', error_msg).perform
    end
  end
end
