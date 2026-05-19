# Static helper class wrapping the TikTok Shop Open Platform OAuth endpoints.
#
# Unlike Lazada (manual creds) and the existing Tiktok Business Messaging
# channel (which uses /tt_user/oauth2/...), TikTok Shop uses a separate auth
# host and a different token shape.
#
# Auth flow:
#   1. authorize_url   → user redirected to TikTok Shop consent screen
#   2. obtain_short_term_access_token(auth_code) → exchanges code for tokens
#   3. renew_short_term_access_token(refresh_token) → refresh
#
# References:
#   https://partner.tiktokshop.com/docv2/page/upgrading-to-api-version-202309 (JS-rendered, content not extracted)
#   https://github.com/EcomPHP/tiktokshop-php (open-source SDK targeting v202309)
class Tiktok::Shop::AuthClient
  AUTH_HOST = 'https://services.tiktokshop.com'.freeze
  TOKEN_HOST = 'https://auth.tiktok-shops.com'.freeze
  # TODO: TikTok Shop has a separate US host for sellers in US region.
  # Confirm hostname before going live for US shops.
  US_TOKEN_HOST = 'https://auth.tiktok-shops.us.com'.freeze

  class << self
    def authorize_url(state: nil)
      params = {
        app_key: client_id,
        state: state
      }.compact

      "#{AUTH_HOST}/open/authorize?#{params.to_query}"
    end

    # Exchange the auth_code from the OAuth callback for a long-lived token set.
    # TikTok Shop returns multiple shops; we use the first one for MVP. Multi-shop
    # support is a follow-up — see TIKTOK_SHOP_INTEGRATION_PLAN.md #8.
    #
    # https://partner.tiktokshop.com/docv2/page/upgrading-to-api-version-202309
    def obtain_short_term_access_token(auth_code, region: 'others')
      endpoint = "#{token_host(region)}/api/v2/token/get"
      params = {
        app_key: client_id,
        app_secret: client_secret,
        auth_code: auth_code,
        grant_type: 'authorized_code'
      }

      response = HTTParty.get(endpoint, query: params, timeout: 30)
      json = process_json_response(response, 'Failed to obtain TikTok Shop access token')

      data = json['data'] || {}
      shops = data['granted_scopes'] || []  # TODO: confirm key name. Some SDKs return shop_list / authorized_shop_list.
      first_shop = (data['shop_list'] || data['authorized_shop_list'] || []).first || {}

      {
        shop_id: first_shop['shop_id'] || data['shop_id'],
        shop_cipher: first_shop['shop_cipher'] || data['shop_cipher'],
        seller_name: data['seller_name'],
        region: data['seller_base_region'] || region,
        access_token: data['access_token'],
        refresh_token: data['refresh_token'],
        access_token_expires_at: Time.current + data['access_token_expire_in'].to_i.seconds,
        refresh_token_expires_at: Time.current + data['refresh_token_expire_in'].to_i.seconds,
        raw_shops: data['shop_list'] || data['authorized_shop_list'] || []
      }.with_indifferent_access
    end

    def renew_short_term_access_token(refresh_token, region: 'others')
      endpoint = "#{token_host(region)}/api/v2/token/refresh"
      params = {
        app_key: client_id,
        app_secret: client_secret,
        refresh_token: refresh_token,
        grant_type: 'refresh_token'
      }

      response = HTTParty.get(endpoint, query: params, timeout: 30)
      json = process_json_response(response, 'Failed to renew TikTok Shop access token')

      data = json['data'] || {}
      {
        access_token: data['access_token'],
        refresh_token: data['refresh_token'],
        access_token_expires_at: Time.current + data['access_token_expire_in'].to_i.seconds,
        refresh_token_expires_at: Time.current + data['refresh_token_expire_in'].to_i.seconds
      }.with_indifferent_access
    end

    private

    def client_id
      GlobalConfigService.load('TIKTOK_SHOP_APP_KEY', nil)
    end

    def client_secret
      GlobalConfigService.load('TIKTOK_SHOP_APP_SECRET', nil)
    end

    def token_host(region)
      region.to_s.casecmp('us').zero? ? US_TOKEN_HOST : TOKEN_HOST
    end

    def process_json_response(response, error_prefix)
      unless response.success?
        Rails.logger.error "#{error_prefix}. Status: #{response.code}, Body: #{response.body}"
        raise "#{response.code}: #{response.body}"
      end

      res = JSON.parse(response.body)
      raise "#{res['code']}: #{res['message']}" if res['code'].to_i != 0

      res
    end
  end
end
