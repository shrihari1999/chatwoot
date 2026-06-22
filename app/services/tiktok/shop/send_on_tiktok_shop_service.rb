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
    # Only images are supported for sending today. Video/file/audio sending needs
    # the chunked Upload File Init -> vid flow (not yet implemented), so surface a
    # clear failure instead of silently dropping the attachment.
    unsupported = message.attachments.reject { |a| a.file_type == 'image' }
    return mark_unsupported_attachments(unsupported) if unsupported.any?

    message.attachments.each { |attachment| send_image_attachment(conversation_id, attachment) }
    send_text(conversation_id) if message.outgoing_content.present?
  end

  def send_image_attachment(conversation_id, attachment)
    uploaded = client.upload_image(attachment.file.download)
    return handle_failed_upload(uploaded) unless uploaded.success?

    data = uploaded.body['data'] || {}
    response = client.send_image(conversation_id, url: data['url'], width: data['width'], height: data['height'])
    handle_response(response)
  end

  def mark_unsupported_attachments(attachments)
    types = attachments.map(&:file_type).uniq.join(', ')
    error_msg = "TikTok Shop does not support sending #{types} attachments"
    Rails.logger.warn("[TikTok Shop] #{error_msg} (message #{message.id})")
    Messages::StatusUpdateService.new(message, 'failed', error_msg).perform
  end

  def handle_response(response)
    if response.success?
      message_id = response.body.dig('data', 'message_id')
      message.update!(source_id: message_id) if message_id.present?
      # TikTok Shop sends NO delivery/read webhooks (its event catalog has only
      # 13/14/33 — new conversation / new message / creator message). A successful
      # send returns a message_id, the strongest confirmation we will get that
      # TikTok accepted and posted the message, so mark it delivered rather than
      # leaving it perpetually at "sent" (which renders as a pending clock).
      Messages::StatusUpdateService.new(message, 'delivered').perform
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
