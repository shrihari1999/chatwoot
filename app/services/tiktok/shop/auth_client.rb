# OAuth helper for the TikTok Shop Open Platform.
#
# Refs (from Partner Center docs):
#   Authorization guide (202309): docs/integrations/TIKTOK_SHOP_INTEGRATION_PLAN.md
#   - Auth URL host varies by region: services.tiktokshop.com vs services.us.tiktokshop.com
#   - Token endpoints are GET (not POST), at auth.tiktok-shops.com/api/v2/token/{get,refresh}
#   - Token response gives Unix-timestamps (absolute), not durations
#   - Token response does NOT include shop_cipher — must call Get Authorized Shops
#     (/authorization/202309/shops) afterwards with the access_token to obtain it.
class Tiktok::Shop::AuthClient
  AUTH_HOST_GLOBAL = 'https://services.tiktokshop.com'.freeze
  AUTH_HOST_US     = 'https://services.us.tiktokshop.com'.freeze
  TOKEN_HOST       = 'https://auth.tiktok-shops.com'.freeze
  # NB: docs don't differentiate token host for US sellers — only the
  # authorize URL host differs. Token exchange is the same auth.tiktok-shops.com.

  class << self
    # Build the seller authorization URL. The seller (TikTok Shop owner) opens
    # this URL, logs in, approves access, and is redirected to the app's
    # Redirect URL with `?code=<auth_code>&state=<state>`.
    #
    # `service_id` is the app's per-app OAuth client identifier from Partner
    # Center → App details. It is distinct from `app_key`.
    # Both US and non-US sellers can use the global authorize host; the US
    # host exists for the US-restricted Partner Center but redirects work
    # either way for SEA/Thai sellers.
    def authorize_url(state: nil, region: 'others')
      return if service_id.blank?

      base = region.to_s.casecmp('us').zero? ? AUTH_HOST_US : AUTH_HOST_GLOBAL
      params = { service_id: service_id, state: state }.compact
      "#{base}/open/authorize?#{params.to_query}"
    end

    # Exchange the auth_code from the OAuth callback for a long-lived token set.
    # GET request; all parameters in the query string. Returns Unix timestamps
    # for both token expiries (absolute, not seconds-from-now).
    #
    # The response does NOT contain shop_cipher. Caller MUST follow up with
    # fetch_authorized_shops(access_token) to get the cipher needed for API
    # calls.
    def obtain_access_token(auth_code)
      raise 'TIKTOK_SHOP_APP_KEY / TIKTOK_SHOP_APP_SECRET not configured' if app_key.blank? || app_secret.blank?

      endpoint = "#{TOKEN_HOST}/api/v2/token/get"
      params = {
        app_key: app_key,
        app_secret: app_secret,
        auth_code: auth_code,
        grant_type: 'authorized_code'
      }
      response = HTTParty.get(endpoint, query: params, timeout: 30)
      data = process_response(response, 'Failed to obtain TikTok Shop access token')

      build_token_hash(data)
    end

    def renew_access_token(refresh_token)
      raise 'TIKTOK_SHOP_APP_KEY / TIKTOK_SHOP_APP_SECRET not configured' if app_key.blank? || app_secret.blank?

      endpoint = "#{TOKEN_HOST}/api/v2/token/refresh"
      params = {
        app_key: app_key,
        app_secret: app_secret,
        refresh_token: refresh_token,
        grant_type: 'refresh_token'
      }
      response = HTTParty.get(endpoint, query: params, timeout: 30)
      data = process_response(response, 'Failed to renew TikTok Shop access token')

      build_token_hash(data)
    end

    # Fetch the list of shops the seller has authorized this app for.
    # https://partner.tiktokshop.com/docv2/page/get-authorized-shops
    # Returns an array of { id, cipher, code, name, region, seller_type }.
    def fetch_authorized_shops(access_token)
      path = '/authorization/202309/shops'
      timestamp = Time.current.to_i.to_s
      query = { app_key: app_key, timestamp: timestamp }
      query[:sign] = Tiktok::Shop::SignatureService.generate(path: path, query: query, body: nil, app_secret: app_secret)

      response = HTTParty.get(
        "#{Tiktok::Shop::Client::API_BASE}#{path}",
        query: query,
        headers: { 'x-tts-access-token' => access_token, 'Content-Type' => 'application/json' },
        timeout: 30
      )
      data = process_response(response, 'Failed to fetch authorized shops')
      Array(data['shops']).map(&:with_indifferent_access)
    end

    private

    def build_token_hash(data)
      {
        access_token: data['access_token'],
        refresh_token: data['refresh_token'],
        # Unix timestamps — convert to Time objects for storage.
        access_token_expires_at: Time.zone.at(data['access_token_expire_in'].to_i),
        refresh_token_expires_at: Time.zone.at(data['refresh_token_expire_in'].to_i),
        open_id: data['open_id'],
        seller_name: data['seller_name'],
        seller_base_region: data['seller_base_region'],
        user_type: data['user_type']
      }.with_indifferent_access
    end

    def process_response(response, error_prefix)
      unless response.success?
        Rails.logger.error "#{error_prefix}. Status: #{response.code}, Body: #{response.body}"
        raise "#{response.code}: #{response.body}"
      end

      json = JSON.parse(response.body)
      raise "#{json['code']}: #{json['message']}" if json['code'].to_i != 0

      json['data'] || {}
    end

    def service_id
      GlobalConfigService.load('TIKTOK_SHOP_SERVICE_ID', nil)
    end

    def app_key
      GlobalConfigService.load('TIKTOK_SHOP_APP_KEY', nil)
    end

    def app_secret
      GlobalConfigService.load('TIKTOK_SHOP_APP_SECRET', nil)
    end
  end
end
