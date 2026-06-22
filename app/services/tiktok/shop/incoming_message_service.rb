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

  # Buyer "enter" events that carry useful context (which product/order/transfer
  # the buyer arrived from). These are surfaced even when the sender role is not
  # strictly BUYER, since the platform may emit them with a system-ish role.
  CONTEXT_ENTER_TYPES = %w[BUYER_ENTER_FROM_PRODUCT BUYER_ENTER_FROM_ORDER BUYER_ENTER_FROM_TRANSFER].freeze

  # Types whose content is plain conversational text carried in content['content'].
  TEXT_LIKE_TYPES = %w[TEXT ALLOCATED_SERVICE NOTIFICATION BUYER_ENTER_FROM_TRANSFER OTHER].freeze

  def perform
    return if data.blank?
    return unless ingestible?        # buyer-originated traffic + buyer-context enter events
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

  def ingestible?
    buyer_message? || context_enter_message?
  end

  def buyer_message?
    data[:sender].is_a?(Hash) && data[:sender][:role].to_s == 'BUYER'
  end

  def context_enter_message?
    CONTEXT_ENTER_TYPES.include?(msg_type)
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
    enqueue_profile_enrichment
  end

  # The webhook only carries the buyer's im_user_id (no name/avatar), so the
  # contact is created with the id as a placeholder name. Fetch the buyer's
  # nickname + avatar from the API in the background, once per buyer.
  def enqueue_profile_enrichment
    return if data[:conversation_id].blank?
    return unless @contact.name.blank? || @contact.name == im_user_id || !@contact.avatar.attached?

    Tiktok::Shop::ContactProfileJob.perform_later(
      channel_id: channel.id,
      contact_id: @contact.id,
      conversation_id: data[:conversation_id].to_s,
      im_user_id: im_user_id
    )
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
    return content_hash['content'].to_s if TEXT_LIKE_TYPES.include?(msg_type)
    return '' if %w[IMAGE VIDEO].include?(msg_type) # rendered via attachment

    card_summary
  end

  def card_summary
    case msg_type
    when 'PRODUCT_CARD'
      "Product: #{content_hash['product_id']}"
    when 'BUYER_ENTER_FROM_PRODUCT'
      "Buyer started chat from product #{content_hash['product_id']}"
    when 'ORDER_CARD'
      "Order: #{content_hash['order_id']}"
    when 'BUYER_ENTER_FROM_ORDER'
      "Buyer started chat from order #{content_hash['order_id']}"
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
    download_and_attach(:image)
  end

  def attach_video
    download_and_attach(:video)
  end

  # TikTok Shop media URLs are time-limited signed CDN links, so we download the
  # bytes into storage rather than persisting the ephemeral URL. Falls back to the
  # remote URL if the download fails, so a CDN hiccup never drops the message.
  def download_and_attach(file_type)
    url = content_hash['url']
    return if url.blank?

    file = Down.download(url)
    build_attachment(file_type, file: { io: file, filename: file.original_filename, content_type: file.content_type })
  rescue StandardError => e
    Rails.logger.error("TikTok Shop #{file_type} download failed for message #{data[:message_id]}: #{e.class}: #{e.message}")
    build_attachment(file_type, external_url: url)
  end

  def build_attachment(file_type, attrs)
    @message.attachments.new({ account_id: channel.inbox.account_id, file_type: file_type }.merge(attrs))
  end
end
