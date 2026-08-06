class Lazada::IncomingMessageService
  include ::FileTypeHelper

  # Lazada's "sem_seller_engagement_push" marketing broadcast — ads for seller
  # webinars and promos, pushed down the same webhook as buyer chat.
  MARKETING_PUSH_TEMPLATE_ID = 200_016

  pattr_initialize [:inbox!, :params!]

  def perform
    data = params[:data]
    return if data.blank?

    # These carry raw HTML in their content, which the dashboard escapes into
    # visible markup (markdown-it runs with html: false), and every one of them
    # opens a conversation that auto-assignment hands to an agent. Nothing in
    # them is actionable by the shop, so drop them before any contact or
    # conversation exists. The sending account also posts ordinary system
    # messages, so we key on the template, not the sender.
    return log_dropped_marketing_push(data) if marketing_push?(data)

    # Recall webhooks (status=1) must be handled regardless of sender. Sellers
    # can recall their own outgoing messages too, and we still want to mark
    # those as deleted in Chatwoot.
    if recalled_message?(data)
      Lazada::IncomingRecallService.new(inbox: inbox, params: params).perform
      return
    end

    if seller_message?(data)
      ingest_echo(data)
    else
      ingest_incoming(data)
    end
  end

  private

  def ingest_incoming(data)
    set_contact(data)
    set_conversation(data)
    create_message(data)
    attach_image(data) if image_message?(data)
    @message.save!
  end

  # A seller-side echo (sent from the Lazada seller app): the sender is the
  # seller, not the buyer, so we can't build a contact from it — attach it to the
  # buyer's existing conversation (keyed by lazada_session_id). Skip if the buyer
  # has never messaged. Our own Chatwoot sends echo back too, so dedup on
  # source_id (the send path stores Lazada's message_id there).
  def ingest_echo(data)
    @conversation = echo_conversation(data)
    return if @conversation.blank?
    return if echo_duplicate?(data)

    create_message(data, message_type: :outgoing, echo: true)
    attach_image(data) if image_message?(data)
    @message.save!
  end

  def seller_message?(data)
    data[:from_account_type].to_i == 2
  end

  def marketing_push?(data)
    data[:template_id].to_i == MARKETING_PUSH_TEMPLATE_ID
  end

  # Logged so we can confirm the drop is firing, and notice it if Lazada ever
  # repurposes the template for something the shop needs to see.
  def log_dropped_marketing_push(data)
    Rails.logger.info(
      "Lazada marketing push dropped (template #{MARKETING_PUSH_TEMPLATE_ID}): " \
      "message_id=#{data[:message_id]} session_id=#{data[:session_id]}"
    )
    nil
  end

  # A resolved-then-reopened buyer thread can leave several Chatwoot conversations
  # sharing one lazada_session_id, so take the most recent — the same one the
  # buyer's live messages land in (see set_conversation).
  def echo_conversation(data)
    session_id = data[:session_id].to_s
    return if session_id.blank?

    ::Conversation.where(inbox_id: inbox.id)
                  .where("additional_attributes->>'lazada_session_id' = ?", session_id)
                  .order(created_at: :desc)
                  .first
  end

  def echo_duplicate?(data)
    @conversation.messages.exists?(source_id: data[:message_id].to_s)
  end

  def recalled_message?(data)
    data[:status].to_i == 1
  end

  def image_message?(data)
    data[:template_id].to_i == 3
  end

  def set_contact(data)
    # Lazada sends from_user_id, not from_account_id
    user_id = (data[:from_user_id] || data[:from_account_id]).to_s
    
    contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: user_id,
      inbox: inbox,
      contact_attributes: {
        name: user_id,
        additional_attributes: {
          lazada_account_id: user_id,
          lazada_site_id: data[:site_id]
        }
      }
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
    enqueue_contact_profile(data)
  end

  # The PUSH carries no avatar, so fetch the buyer's head_url from the API in the
  # background. Buyer messages only (seller messages return earlier), and only
  # while the avatar is missing so it runs effectively once per contact.
  def enqueue_contact_profile(data)
    return if data[:session_id].blank?
    return if @contact.avatar.attached?

    Lazada::ContactProfileJob.perform_later(
      channel_id: inbox.channel.id,
      contact_id: @contact.id,
      session_id: data[:session_id].to_s
    )
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

  def create_message(data, message_type: :incoming, echo: false)
    @message = @conversation.messages.build(
      content: parse_content(data),
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: message_type,
      source_id: data[:message_id].to_s,
      content_attributes: {
        lazada_template_id: data[:template_id],
        external_echo: (true if echo)
      }.compact
    )
    # For an echo the seller is the sender, so we leave sender unset (an outgoing
    # message with no user sender) and mark it delivered — Lazada already
    # delivered it to the buyer.
    @message.sender = @contact unless echo
    @message.status = :delivered if echo
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

    # Lazada CDN image URLs are time-limited, so download the bytes into storage
    # rather than persisting the ephemeral URL. Falls back to the remote URL if the
    # download fails, so a CDN hiccup never drops the message.
    file = Down.download(img_url)
    build_image_attachment(file: { io: file, filename: file.original_filename, content_type: file.content_type })
  rescue StandardError => e
    Rails.logger.error("Lazada image download failed: #{e.class}: #{e.message}")
    build_image_attachment(external_url: img_url)
  end

  def build_image_attachment(attrs)
    @message.attachments.new({ account_id: inbox.account_id, file_type: :image }.merge(attrs))
  end

  def safe_parse_json(str)
    JSON.parse(str)
  rescue JSON::ParserError, TypeError
    nil
  end
end
