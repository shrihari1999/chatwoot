# Verifies the signature on an inbound TikTok Shop webhook delivery.
#
# TikTok Shop signs webhook DELIVERIES as HMAC-SHA256(app_secret, app_key + raw_body),
# hex-encoded, delivered in the `Authorization` header. (This differs from the
# outgoing API-request signing in Tiktok::Shop::SignatureService — no path, no
# query params, no app_secret wrapping.)
#
# Shared by the controller (to reject with 401 before enqueuing) and the events
# job (defense in depth).
class Tiktok::Shop::WebhookSignatureService
  def self.valid?(raw_body:, signature:)
    return false if signature.blank?

    app_key = GlobalConfigService.load('TIKTOK_SHOP_APP_KEY', nil)
    app_secret = GlobalConfigService.load('TIKTOK_SHOP_APP_SECRET', nil)
    return false if app_key.blank? || app_secret.blank?

    expected = OpenSSL::HMAC.hexdigest('SHA256', app_secret, "#{app_key}#{raw_body}")
    ActiveSupport::SecurityUtils.secure_compare(expected, signature.to_s.downcase)
  end
end
