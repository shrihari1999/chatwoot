# Handles inbound TikTok Shop messages. Mirrors Lazada::IncomingMessageService.
# Payload schema is partially known — fields marked TODO need Partner Center
# verification.
class Tiktok::Shop::IncomingMessageService
  include ::FileTypeHelper
  pattr_initialize [:channel!, :payload!]

  def perform
    return if data.blank?
    return if seller_message?

    set_contact
    set_conversation
    create_message
    attach_image if image_message?
    @message.save!
  end

  private

  def inbox
    @inbox ||= channel.inbox
  end

  def data
    @data ||= payload[:data] || payload
  end

  # TikTok Shop distinguishes seller vs buyer messages by sender role.
  # TODO: confirm the field name and enum values.
  def seller_message?
    %w[SELLER seller business_account].include?(data[:sender_role].to_s)
  end

  def image_message?
    data[:type].to_s.casecmp('IMAGE').zero?
  end

  def set_contact
    # TODO: TikTok Shop returns the buyer identifier as `buyer_user_id` or
    # `sender_user_id` depending on the event. Confirm field name.
    user_id = (data[:buyer_user_id] || data[:sender_user_id] || data[:user_id]).to_s

    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: user_id,
      inbox: inbox,
      contact_attributes: {
        name: data[:buyer_name] || data[:sender_name] || user_id,
        additional_attributes: {
          tiktok_shop_user_id: user_id,
          tiktok_shop_id: channel.shop_id
        }
      }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def set_conversation
    @conversation = if inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end
    return if @conversation

    @conversation = ::Conversation.create!(
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: {
        tiktok_shop_conversation_id: data[:conversation_id],
        tiktok_shop_id: channel.shop_id
      }
    )
  end

  def create_message
    @message = @conversation.messages.build(
      content: parse_content,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: data[:message_id].to_s,
      content_attributes: {
        tiktok_shop_type: data[:type],
        tiktok_shop_raw: data.slice(:product_id, :order_id, :sku_id).compact_blank
      }
    )
  end

  def parse_content
    case data[:type].to_s.upcase
    when 'TEXT'
      data.dig(:content, :text) || data[:content]
    when 'IMAGE'
      ''
    when 'PRODUCT_CARD'
      # TODO: confirm field structure for product cards.
      "Product: #{data.dig(:content, :product_id) || data[:product_id]}"
    when 'ORDER_CARD'
      "Order: #{data.dig(:content, :order_id) || data[:order_id]}"
    when 'STICKER'
      data.dig(:content, :sticker_id) ? "[sticker]" : ''
    else
      # Fall through with raw content so we don't drop unknown types silently.
      data[:content].is_a?(String) ? data[:content] : data[:content].to_json
    end
  end

  def attach_image
    # TODO: image attachment URL field name. The PHP SDK references an `image_url`
    # but Shop API may return media_id requiring a separate fetch via
    # /customer_service/202309/images/{media_id} (TODO confirm path).
    image_url = data.dig(:content, :image_url) || data[:image_url]
    return if image_url.blank?

    @message.attachments.new(
      account_id: inbox.account_id,
      file_type: :image,
      external_url: image_url
    )
  end
end
