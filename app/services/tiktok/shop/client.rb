# HTTP client wrapping the TikTok Shop Open Platform Customer Service API
# (version 202309). Constructed per-channel so it can pick the right access
# token + shop_cipher for every request.
#
# Endpoint inventory comes from https://github.com/EcomPHP/tiktokshop-php
# (CustomerService.php). The signing convention is the standard TikTok Shop
# scheme: HMAC-SHA256 over `<app_secret>` + concatenated sorted params (excluding
# `sign` and `access_token`) + (for POSTs) the raw JSON body + `<app_secret>`.
# TODO: confirm the precise input string format against Partner Center docs
# before going live — the SDK source is the only public reference.
class Tiktok::Shop::Client
  API_BASE = 'https://open-api.tiktokglobalshop.com'.freeze
  API_VERSION = '202309'.freeze

  pattr_initialize [:channel!]

  # ---- Customer Service endpoints -----------------------------------------

  def get_conversations(page_size: 20, next_page_token: nil)
    params = { page_size: page_size, next_page_token: next_page_token }.compact
    request(:get, '/customer_service/202309/conversations', query: params)
  end

  def get_conversation_messages(conversation_id, page_size: 20, next_page_token: nil, sort_order: 'DESC')
    params = { page_size: page_size, next_page_token: next_page_token, sort_order: sort_order }.compact
    request(:get, "/customer_service/202309/conversations/#{conversation_id}/messages", query: params)
  end

  def send_message(conversation_id, type:, content:)
    body = { type: type, content: content }
    request(:post, "/customer_service/202309/conversations/#{conversation_id}/messages", body: body)
  end

  def mark_conversation_read(conversation_id)
    request(:post, "/customer_service/202309/conversations/#{conversation_id}/messages/read")
  end

  def upload_image(file)
    # TODO: TikTok Shop image upload uses multipart/form-data with form key `data`.
    # Confirm key name and any required metadata fields once Partner Center docs
    # are accessible.
    request_multipart('/customer_service/202309/images/upload', file: file)
  end

  def create_conversation(buyer_user_id)
    request(:post, '/customer_service/202309/conversations', body: { buyer_user_id: buyer_user_id })
  end

  def get_authorized_shops
    request(:get, '/authorization/202309/shops')
  end

  # TODO: TikTok Shop reactions / recall / reply endpoints are not exposed by the
  # public EcomPHP SDK. If Partner Center docs reveal them, add methods here:
  #   def react_to_message(conversation_id, message_id, emoji)
  #   def recall_message(conversation_id, message_id)
  #   def reply_to_message(conversation_id, parent_message_id, ...)

  private

  def request(method, path, query: {}, body: nil)
    timestamp = Time.current.to_i.to_s
    sys_params = {
      app_key: app_key,
      shop_cipher: channel.shop_cipher,
      timestamp: timestamp,
      version: API_VERSION,
      access_token: channel.validated_access_token
    }

    signed_query = sys_params.merge(query.transform_keys(&:to_sym))
    signed_query[:sign] = generate_sign(path, signed_query, body)

    url = "#{API_BASE}#{path}"
    response = case method
               when :get
                 HTTParty.get(url, query: signed_query, timeout: 30)
               when :post
                 HTTParty.post(url, query: signed_query, body: body&.to_json, headers: { 'Content-Type' => 'application/json' }, timeout: 30)
               end

    parse_response(response)
  end

  def request_multipart(path, file:)
    timestamp = Time.current.to_i.to_s
    sys_params = {
      app_key: app_key,
      shop_cipher: channel.shop_cipher,
      timestamp: timestamp,
      version: API_VERSION,
      access_token: channel.validated_access_token
    }
    # Multipart requests don't include the body in the signature.
    sys_params[:sign] = generate_sign(path, sys_params, nil)

    url = "#{API_BASE}#{path}"
    response = HTTParty.post(url, query: sys_params, body: { data: file }, timeout: 60)
    parse_response(response)
  end

  # TikTok Shop signing — based on EcomPHP/tiktokshop-php convention.
  # Sign = HMAC-SHA256 of: <app_secret> + <path> + <sorted params concatenated as k+v> + <body if not multipart> + <app_secret>
  # TODO: verify exactly which params are excluded — the SDK excludes `sign`, `access_token`, and content-type.
  def generate_sign(path, params, body)
    excluded_keys = %i[sign access_token]
    sorted = params.except(*excluded_keys).sort_by { |k, _| k.to_s }
    string_to_sign = +"#{app_secret}#{path}"
    sorted.each { |k, v| string_to_sign << "#{k}#{v}" }
    string_to_sign << body.to_json if body.present?
    string_to_sign << app_secret

    OpenSSL::HMAC.hexdigest('SHA256', app_secret, string_to_sign)
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
