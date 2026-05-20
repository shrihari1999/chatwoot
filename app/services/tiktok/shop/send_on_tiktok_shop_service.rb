# Outbound message dispatcher for TikTok Shop.
#
# TikTok Shop Send Message body shape:
#   { "type": "TEXT" | "IMAGE" | "VIDEO" | "PRODUCT_CARD" | ... ,
#     "content": "<JSON-serialized string of the type-specific payload>" }
#
# Sending requires:
#   - The buyer has messaged the shop in the last 30 days, OR
#   - The buyer placed an order in the last 60 days, OR
#   - The buyer has a return/refund history with the shop.
# The `can_send_message` flag on a conversation indicates eligibility — we
# don't pre-check here; we let the API return its eligibility error.
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
      send_text(conversation_id) if message.outgoing_content.present?
    end
  end

  def send_text(conversation_id)
    response = client.send_text(conversation_id, message.outgoing_content)
    handle_response(response)
  end

  def send_attachments(conversation_id)
    message.attachments.each do |attachment|
      next unless attachment.file_type == 'image'

      uploaded = client.upload_image(attachment.file.download)
      next handle_failed_upload(uploaded) unless uploaded.success?

      data = uploaded.body['data'] || {}
      response = client.send_image(
        conversation_id,
        url: data['url'],
        width: data['width'],
        height: data['height']
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

  def handle_failed_upload(response)
    error_msg = response.body&.dig('message') || "TikTok Shop image upload error: #{response.code}"
    Rails.logger.error "[TikTok Shop] Image upload failed: #{error_msg}"
    Messages::StatusUpdateService.new(message, 'failed', error_msg).perform
  end

  def client
    @client ||= Tiktok::Shop::Client.new(channel: channel)
  end
end
