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
    message.attachments.each do |attachment|
      next unless attachment.file_type == 'image'

      response = channel.send_im_message(
        session_id: session_id,
        template_id: 3,
        img_url: attachment.download_url
      )
      handle_response(response)
    end

    send_text(session_id) if message.outgoing_content.present?
  end

  def handle_response(response)
    if response.success?
      message_id = response.body.dig('data', 'message_id')
      message.update!(source_id: message_id) if message_id.present?
    else
      error_msg = response.body&.dig('message') || "Lazada API error: #{response.code}"
      Messages::StatusUpdateService.new(message, 'failed', error_msg).perform
    end
  end
end
