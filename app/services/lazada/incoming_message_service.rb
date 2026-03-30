class Lazada::IncomingMessageService
  include ::FileTypeHelper
  pattr_initialize [:inbox!, :params!]

  def perform
    data = params[:data]
    return if data.blank?
    return if seller_message?(data)
    return if recalled_message?(data)

    set_contact(data)
    set_conversation(data)
    create_message(data)
    attach_image(data) if image_message?(data)
    @message.save!
  end

  private

  def seller_message?(data)
    data[:from_account_type].to_i == 2
  end

  def recalled_message?(data)
    data[:status].to_i == 1
  end

  def image_message?(data)
    data[:template_id].to_i == 3
  end

  def set_contact(data)
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: data[:from_account_id].to_s,
      inbox: inbox,
      contact_attributes: {
        name: data[:from_account_id].to_s,
        additional_attributes: {
          lazada_account_id: data[:from_account_id].to_s,
          lazada_site_id: data[:site_id]
        }
      }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def set_conversation(data)
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
        lazada_session_id: data[:session_id],
        lazada_site_id: data[:site_id]
      }
    )
  end

  def create_message(data)
    content = parse_content(data)

    @message = @conversation.messages.build(
      content: content,
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: data[:message_id].to_s,
      content_attributes: { lazada_template_id: data[:template_id] }
    )
  end

  def parse_content(data)
    content_json = safe_parse_json(data[:content])
    return data[:content] if content_json.nil?

    case data[:template_id].to_i
    when 1 # normal text
      content_json['txt']
    when 2 # system message
      content_json['txt']
    when 3 # picture — content is handled via attachment
      ''
    when 4 # emoji
      content_json['txt']
    when 10_006 # item card
      "Item: #{content_json['itemId'] || content_json['item_id']}"
    when 10_007 # order card
      "Order: #{content_json['orderId'] || content_json['order_id']}"
    else
      content_json['txt'] || data[:content]
    end
  end

  def attach_image(data)
    content_json = safe_parse_json(data[:content])
    return if content_json.nil?

    img_url = content_json['imgUrl']
    return if img_url.blank?

    @message.attachments.new(
      account_id: inbox.account_id,
      file_type: :image,
      external_url: img_url
    )
  end

  def safe_parse_json(str)
    JSON.parse(str)
  rescue JSON::ParserError, TypeError
    nil
  end
end
