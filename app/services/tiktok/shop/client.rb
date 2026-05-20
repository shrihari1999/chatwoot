# HTTP client for the TikTok Shop Open Platform Customer Service API (v202309).
#
# Constructed per-channel so it can supply the correct access_token and
# shop_cipher per request. All requests must:
#   - include `app_key`, `timestamp`, `sign` (and usually `shop_cipher`) in query
#   - send the access token in the `x-tts-access-token` HEADER (not query)
#   - have `sign` calculated via Tiktok::Shop::SignatureService
#
# Refs:
#   API base: open-api.tiktokglobalshop.com
#   Endpoints: docs/integrations/TIKTOK_SHOP_INTEGRATION_PLAN.md
class Tiktok::Shop::Client
  API_BASE = 'https://open-api.tiktokglobalshop.com'.freeze

  pattr_initialize [:channel!]

  # ---- Customer Service endpoints ----------------------------------------

  def get_conversations(page_size: 20, page_token: nil, need_session_id: false, locale: 'en')
    request(:get, '/customer_service/202309/conversations', query: {
      page_size: page_size,
      page_token: page_token,
      need_session_id: need_session_id,
      locale: locale
    }.compact)
  end

  def get_conversation_messages(conversation_id, page_size: 10, page_token: nil, sort_order: 'DESC')
    request(:get, "/customer_service/202309/conversations/#{conversation_id}/messages", query: {
      page_size: page_size, page_token: page_token, sort_order: sort_order
    }.compact)
  end

  # type: TEXT, IMAGE, VIDEO, PRODUCT_CARD, ORDER_CARD, RETURN_REFUND_CARD,
  #       COUPON_CARD, LOGISTICS_CARD
  # content_payload: a Hash that will be JSON-encoded and assigned to `content`.
  # Per the docs, the `content` body field is itself a JSON-serialized string.
  def send_message(conversation_id, type:, content_payload:)
    body = { type: type, content: content_payload.to_json }
    request(:post, "/customer_service/202309/conversations/#{conversation_id}/messages", body: body)
  end

  # Marks all buyer-sent messages in this conversation as read.
  def mark_conversation_read(conversation_id)
    request(:post, "/customer_service/202309/conversations/#{conversation_id}/messages/read", body: {})
  end

  # Uploads a binary image; returns { url, width, height }. Use the returned
  # url/width/height in send_message's IMAGE content payload.
  def upload_image(file)
    request_multipart('/customer_service/202309/images/upload', file: file)
  end

  def create_conversation(buyer_user_id)
    request(:post, '/customer_service/202309/conversations', body: { buyer_user_id: buyer_user_id })
  end

  # ---- Webhook subscription (per-shop) ---------------------------------
  # The Partner Center GUI configures webhooks at the app level. These three
  # endpoints let us do it per-shop via API, which is useful when the GUI
  # misbehaves or when we want programmatic control.
  #
  # event_type uses the STRING names (e.g. 'NEW_MESSAGE', 'NEW_CONVERSATION'),
  # distinct from the NUMERIC type ids that arrive in webhook payloads (14, 13).

  def subscribe_webhook(event_type:, address:)
    request(:put, '/event/202309/webhooks', body: { event_type: event_type, address: address })
  end

  def list_webhooks
    request(:get, '/event/202309/webhooks')
  end

  def delete_webhook(event_type:)
    request(:delete, '/event/202309/webhooks', body: { event_type: event_type })
  end

  # ---- Convenience ------------------------------------------------------

  def send_text(conversation_id, text)
    send_message(conversation_id, type: 'TEXT', content_payload: { content: text })
  end

  def send_image(conversation_id, url:, width:, height:)
    send_message(conversation_id, type: 'IMAGE', content_payload: { url: url, width: width, height: height })
  end

  private

  def request(method, path, query: {}, body: nil) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    sys = { app_key: app_key, timestamp: Time.current.to_i.to_s }
    sys[:shop_cipher] = channel.shop_cipher if channel.shop_cipher.present?
    full_query = sys.merge(query.transform_keys(&:to_sym).compact)

    body_string = if body.is_a?(String)
                    body
                  else
                    (body.nil? ? nil : body.to_json)
                  end
    full_query[:sign] = Tiktok::Shop::SignatureService.generate(
      path: path, query: full_query, body: body_string, app_secret: app_secret
    )

    url = "#{API_BASE}#{path}"
    headers = {
      'x-tts-access-token' => channel.validated_access_token,
      'Content-Type' => 'application/json'
    }

    response = case method
               when :get
                 HTTParty.get(url, query: full_query, headers: headers, timeout: 30)
               when :post
                 HTTParty.post(url, query: full_query, body: body_string, headers: headers, timeout: 30)
               when :put
                 HTTParty.put(url, query: full_query, body: body_string, headers: headers, timeout: 30)
               when :delete
                 HTTParty.delete(url, query: full_query, body: body_string, headers: headers, timeout: 30)
               end

    parse_response(response)
  end

  def request_multipart(path, file:)
    sys = { app_key: app_key, timestamp: Time.current.to_i.to_s }
    sys[:shop_cipher] = channel.shop_cipher if channel.shop_cipher.present?
    # Per docs: body is NOT included in the signature when Content-Type is multipart/form-data.
    sys[:sign] = Tiktok::Shop::SignatureService.generate(path: path, query: sys, body: nil, app_secret: app_secret)

    headers = { 'x-tts-access-token' => channel.validated_access_token }
    response = HTTParty.post("#{API_BASE}#{path}", query: sys, body: { data: file }, headers: headers, timeout: 60)
    parse_response(response)
  end

  def parse_response(response)
    parsed = response.parsed_response
    parsed = JSON.parse(parsed) if parsed.is_a?(String)
    OpenStruct.new(
      success?: parsed['code'].to_i == 0,
      code: parsed['code'],
      body: parsed,
      message: parsed['message']
    )
  rescue JSON::ParserError, TypeError
    OpenStruct.new(success?: false, code: 'PARSE_ERROR', body: {}, message: 'Failed to parse API response')
  end

  def app_key
    GlobalConfigService.load('TIKTOK_SHOP_APP_KEY', nil)
  end

  def app_secret
    GlobalConfigService.load('TIKTOK_SHOP_APP_SECRET', nil)
  end
end
