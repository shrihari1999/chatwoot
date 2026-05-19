# Outbound message dispatcher for TikTok Shop. Sends text or image messages
# to a conversation, then updates the Chatwoot message with the returned
# message_id and status.
class Tiktok::Shop::SendOnTiktokShopService < Base::SendOnChannelService
  private

  def channel_class
    Channel::TiktokShop
  end

  def perform_reply
    conversation_id = conversation.additional_attributes['tiktok_shop_conversation_id']
    return unless conversation_id

    if message.attachments.present?
      send_attachments(conversation_id)
    else
      send_text(conversation_id)
    end
  end

  def send_text(conversation_id)
    response = client.send_message(
      conversation_id,
      type: 'TEXT',
      content: { text: message.outgoing_content }
    )
    handle_response(response)
  end

  def send_attachments(conversation_id)
    message.attachments.each do |attachment|
      next unless attachment.file_type == 'image'

      upload = client.upload_image(attachment.file.download)
      next unless upload.success?

      media_id = upload.body.dig('data', 'media_id') || upload.body.dig('data', 'url')
      response = client.send_message(
        conversation_id,
        type: 'IMAGE',
        # TODO: confirm whether send-message accepts media_id or image_url for the IMAGE type.
        content: { image_url: media_id }
      )
      handle_response(response)
    end

    send_text(conversation_id) if message.outgoing_content.present?
  end

  def handle_response(response)
    if response.success?
      message_id = response.body.dig('data', 'message_id')
      message.update!(source_id: message_id) if message_id.present?
      Messages::StatusUpdateService.new(message, 'sent').perform
    else
      error_msg = response.body&.dig('message') || "TikTok Shop API error: #{response.code}"
      Rails.logger.error "[TikTok Shop] Send failed: #{error_msg}"
      Messages::StatusUpdateService.new(message, 'failed', error_msg).perform
    end
  end

  def client
    @client ||= Tiktok::Shop::Client.new(channel: channel)
  end
end
