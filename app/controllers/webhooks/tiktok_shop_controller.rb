# Receives webhook events from the TikTok Shop Open Platform. Signature
# verification and event dispatch happen in the async job to keep this endpoint
# fast (TikTok expects 200 OK quickly or it will retry and may auto-disable the
# subscription).
class Webhooks::TiktokShopController < ActionController::API
  def events
    Webhooks::TiktokShopEventsJob.perform_later(
      raw_body: request.raw_post,
      signature: request.headers['X-TTS-Signature'] || request.headers['Authorization'],
      timestamp: request.headers['X-TTS-Timestamp']
    )
    head :ok
  end
end
