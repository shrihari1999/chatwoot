class Webhooks::LazadaController < ActionController::API
  def process_payload
    Webhooks::LazadaEventsJob.perform_later(
      params: params.to_unsafe_hash,
      post_body: request.raw_post,
      signature: request.headers['Authorization']
    )
    head :ok
  end
end
