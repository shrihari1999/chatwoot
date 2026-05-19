# Handles inbound TikTok Shop messages (webhook event type 14).
#
# Payload shape (confirmed):
#   data: {
#     conversation_id: "...",
#     message_id: "...",
#     index: "...",                      # numeric-ish string, larger = newer
#     type: "TEXT" | "IMAGE" | "VIDEO" | "PRODUCT_CARD" | "ORDER_CARD" |
#           "LOGISTICS_CARD" | "COUPON_CARD" | "RETURN_REFUND_CARD" |
#           "ALLOCATED_SERVICE" | "NOTIFICATION" | "BUYER_ENTER_FROM_*" | "OTHER"
#     content: "<JSON-serialized string, e.g. {\"content\":\"hi\"}>",
#     create_time: 1681790246,
#     is_visible: true,
#     sender: { im_user_id: "...", role: "BUYER" | "SHOP" | "CUSTOMER_SERVICE" |
#                                        "SYSTEM" | "ROBOT" }
#   }
class Tiktok::Shop::IncomingMessageService
  include ::FileTypeHelper
  pattr_initialize [:channel!, :payload!]

  def perform
    return if data.blank?
    return unless buyer_message?     # only ingest buyer-originated traffic
    return unless visible_message?   # skip rating-request and similar system noise

    set_contact
    set_conversation
    create_message
    attach_image if image_message?
    attach_video if video_message?
    @message.save!
  end

  private

  def data
    @data ||= payload[:data] || payload
  end

  def buyer_message?
    data[:sender].is_a?(Hash) && data[:sender][:role].to_s == 'BUYER'
  end

  def visible_message?
    return true unless data.key?(:is_visible)

    ActiveModel::Type::Boolean.new.cast(data[:is_visible])
  end

  def msg_type
    @msg_type ||= data[:type].to_s.upcase
  end

  def image_message?
    msg_type == 'IMAGE'
  end

  def video_message?
    msg_type == 'VIDEO'
  end

  # Parsed `content` (JSON-serialized string in the webhook).
  def content_hash
    @content_hash ||= begin
      raw = data[:content]
      raw.is_a?(String) ? JSON.parse(raw) : (raw || {})
    rescue JSON::ParserError
      {}
    end
  end

  def im_user_id
    data[:sender][:im_user_id].to_s
  end

  def set_contact
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: im_user_id,
      inbox: channel.inbox,
      contact_attributes: {
        name: data[:sender][:nickname].presence || im_user_id,
        additional_attributes: {
          tiktok_shop_im_user_id: im_user_id,
          tiktok_shop_id: channel.shop_id
        }
      }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def set_conversation
    @conversation = if channel.inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end
    return if @conversation

    @conversation = ::Conversation.create!(
      account_id: channel.inbox.account_id,
      inbox_id: channel.inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: {
        tiktok_shop_conversation_id: data[:conversation_id].to_s,
        tiktok_shop_id: channel.shop_id
      }
    )
  end

  def create_message
    @message = @conversation.messages.build(
      content: parsed_content,
      account_id: channel.inbox.account_id,
      inbox_id: channel.inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: data[:message_id].to_s,
      content_attributes: {
        tiktok_shop_type: msg_type,
        tiktok_shop_index: data[:index],
        tiktok_shop_payload: content_hash
      }
    )
  end

  def parsed_content
    case msg_type
    when 'TEXT', 'ALLOCATED_SERVICE', 'NOTIFICATION', 'BUYER_ENTER_FROM_TRANSFER', 'OTHER'
      content_hash['content'].to_s
    when 'IMAGE', 'VIDEO'
      '' # rendered via attachment
    when 'PRODUCT_CARD', 'BUYER_ENTER_FROM_PRODUCT'
      "Product: #{content_hash['product_id']}"
    when 'ORDER_CARD', 'BUYER_ENTER_FROM_ORDER'
      "Order: #{content_hash['order_id']}"
    when 'LOGISTICS_CARD'
      "Logistics: order #{content_hash['order_id']}"
    when 'RETURN_REFUND_CARD'
      "Return/refund: order #{content_hash['order_id']}"
    when 'COUPON_CARD'
      "Coupon: #{content_hash['coupon_id']}"
    else
      content_hash['content'].to_s
    end
  end

  def attach_image
    url = content_hash['url']
    return if url.blank?

    @message.attachments.new(
      account_id: channel.inbox.account_id,
      file_type: :image,
      external_url: url
    )
  end

  def attach_video
    url = content_hash['url']
    return if url.blank?

    @message.attachments.new(
      account_id: channel.inbox.account_id,
      file_type: :video,
      external_url: url
    )
  end
end
