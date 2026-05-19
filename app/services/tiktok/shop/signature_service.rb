# TikTok Shop API request signing.
#
# Reference: docs/integrations/TIKTOK_SHOP_INTEGRATION_PLAN.md
#   1. Take all query params EXCEPT `sign` and `access_token`, sort alphabetically.
#   2. Concatenate as "key1value1key2value2..."
#   3. Prepend the request path: "/path" + concat.
#   4. If Content-Type is NOT multipart/form-data, append the raw JSON body.
#   5. Wrap the whole string in `app_secret`: secret + step4 + secret.
#   6. HMAC-SHA256 using app_secret as the key, hex-encode lowercase.
class Tiktok::Shop::SignatureService
  EXCLUDED_KEYS = %w[sign access_token].freeze

  class << self
    def generate(path:, query:, body:, app_secret:)
      sorted_params = (query || {})
                      .transform_keys(&:to_s)
                      .reject { |k, _| EXCLUDED_KEYS.include?(k) }
                      .sort_by { |k, _| k }

      concatenated = sorted_params.map { |k, v| "#{k}#{v}" }.join
      input = "#{path}#{concatenated}"
      input += body.to_s if body.present?
      input = "#{app_secret}#{input}#{app_secret}"

      OpenSSL::HMAC.hexdigest('SHA256', app_secret, input)
    end
  end
end
