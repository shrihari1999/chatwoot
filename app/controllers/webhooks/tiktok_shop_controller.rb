# Receives webhook events from TikTok Shop Open Platform.
#
# Per the Configuration guide: TikTok delivers webhooks via HTTPS POST with the
# signature in the `Authorization` header. The signature is computed using the
# same HMAC-SHA256 algorithm as outgoing API calls (Tiktok::Shop::SignatureService).
#
# TikTok requires a 200 (or 401) response within 3 seconds — so we offload the
# verification + dispatch to a job and return 200 immediately.
class Webhooks::TiktokShopController < ActionController::API
  def events
    Webhooks::TiktokShopEventsJob.perform_later(
      raw_body: request.raw_post,
      signature: request.headers['Authorization']
    )
    head :ok
  end
end
