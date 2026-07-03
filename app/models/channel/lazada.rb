class Channel::Lazada < ApplicationRecord
  include Channelable

  if Chatwoot.encryption_configured?
    encrypts :app_secret
    encrypts :access_token
  end

  self.table_name = 'channel_lazada'
  EDITABLE_ATTRS = [:shop_id, :app_key, :app_secret, :access_token].freeze

  API_URL = 'https://api.lazada.co.th/rest'.freeze

  validates :shop_id, uniqueness: true, presence: true
  validates :app_key, presence: true
  validates :app_secret, presence: true
  validates :access_token, presence: true

  def name
    'Lazada'
  end

  def send_im_message(session_id:, template_id:, **params)
    lazada_api_request('/im/message/send', 'POST', {
      template_id: template_id.to_s,
      session_id: session_id
    }.merge(params))
  end

  def get_im_messages(session_id:, start_time:, page_size: 20)
    lazada_api_request('/im/message/list', 'GET', {
      session_id: session_id,
      start_time: start_time.to_s,
      page_size: page_size.to_s
    })
  end

  def get_im_sessions(start_time:, page_size: 20)
    lazada_api_request('/im/session/list', 'GET', {
      start_time: start_time.to_s,
      page_size: page_size.to_s
    })
  end

  # Synchronize a single session by id. Per the IM API best practices this is the
  # sanctioned per-PUSH call (unlike /im/session/list, which must not be polled).
  # Response data includes the buyer's head_url (avatar) and title.
  def get_session_detail(session_id:)
    lazada_api_request('/im/session/get', 'GET', { session_id: session_id })
  end

  # Sync the seller's read status to the buyer. /im/session/read marks both
  # session_id and last_read_message_id as required — omitting the latter makes
  # the read-sync a no-op, so the caller must pass the last read message id.
  def read_session(session_id:, last_read_message_id:)
    lazada_api_request('/im/session/read', 'POST', { session_id: session_id, last_read_message_id: last_read_message_id })
  end

  def recall_im_message(message_id:)
    lazada_api_request('/im/message/recall', 'POST', { message_id: message_id })
  end

  # Resolve a video message's playable URL. The IM video PUSH (template_id 6)
  # carries only a videoId; /media/video/get returns the (signed, time-limited)
  # video_url + cover_url. Ref: https://open.lazada.com/apps/doc/api?path=/media/video/get
  def get_video(video_id:)
    lazada_api_request('/media/video/get', 'GET', { videoId: video_id })
  end

  private

  def lazada_api_request(api_path, http_method, api_params = {})
    sys_params = {
      app_key: app_key,
      sign_method: 'sha256',
      timestamp: (Time.now.to_f * 1000).to_i.to_s,
      access_token: access_token
    }

    all_params = sys_params.merge(api_params.transform_keys(&:to_sym))
    all_params[:sign] = generate_sign(api_path, all_params)

    url = "#{API_URL}#{api_path}"

    response = if http_method == 'POST'
                 HTTParty.post(url, body: all_params, timeout: 30)
               else
                 HTTParty.get(url, query: all_params, timeout: 30)
               end

    handle_response(response)
  end

  def generate_sign(api_path, params)
    sorted_params = params.except(:sign).sort_by { |k, _| k.to_s }
    base_string = api_path + sorted_params.map { |k, v| "#{k}#{v}" }.join
    OpenSSL::HMAC.hexdigest('SHA256', app_secret, base_string).upcase
  end

  def handle_response(response)
    parsed = response.parsed_response
    parsed = JSON.parse(parsed) if parsed.is_a?(String)

    OpenStruct.new(
      success?: parsed['code'] == '0' || parsed['code'] == 0,
      code: parsed['code'],
      body: parsed,
      message: parsed['message']
    )
  rescue JSON::ParserError, TypeError
    OpenStruct.new(success?: false, code: 'PARSE_ERROR', body: {}, message: 'Failed to parse API response')
  end
end
