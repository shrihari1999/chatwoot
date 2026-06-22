# Receives webhook events from TikTok Shop Open Platform.
#
# TikTok delivers webhooks via HTTPS POST with the signature in the `Authorization`
# header (HMAC-SHA256(app_secret, app_key + body), per Tiktok::Shop::WebhookSignatureService).
#
# TikTok requires a 200 (or 401) response within 3 seconds. Signature verification
# is a sub-millisecond HMAC, so we verify synchronously and return 401 on failure
# (so TikTok's retry/alerting can kick in), then offload dispatch to a job and
# return 200 for valid deliveries.
class Webhooks::TiktokShopController < ActionController::API
  def events
    raw_body = request.raw_post
    signature = request.headers['Authorization']

    return head :unauthorized unless Tiktok::Shop::WebhookSignatureService.valid?(raw_body: raw_body, signature: signature)

    Webhooks::TiktokShopEventsJob.perform_later(raw_body: raw_body, signature: signature)
    head :ok
  end
end
