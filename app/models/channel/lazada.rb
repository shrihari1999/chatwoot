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

  def client
    @client ||= LazopApiClient::Client.new(API_URL, app_key, app_secret)
  end

  def send_im_message(session_id:, template_id:, **params)
    request = LazopApiClient::Request.new('/im/message/send')
    request.add_api_parameter('access_token', access_token)
    request.add_api_parameter('template_id', template_id.to_s)
    request.add_api_parameter('session_id', session_id)
    params.each { |key, value| request.add_api_parameter(key.to_s, value.to_s) }
    client.execute(request)
  end

  def get_im_messages(session_id:, start_time:, page_size: 20)
    request = LazopApiClient::Request.new('/im/message/list', 'GET')
    request.add_api_parameter('access_token', access_token)
    request.add_api_parameter('session_id', session_id)
    request.add_api_parameter('start_time', start_time.to_s)
    request.add_api_parameter('page_size', page_size.to_s)
    client.execute(request)
  end

  def get_im_sessions(start_time:, page_size: 20)
    request = LazopApiClient::Request.new('/im/session/list', 'GET')
    request.add_api_parameter('access_token', access_token)
    request.add_api_parameter('start_time', start_time.to_s)
    request.add_api_parameter('page_size', page_size.to_s)
    client.execute(request)
  end
end
