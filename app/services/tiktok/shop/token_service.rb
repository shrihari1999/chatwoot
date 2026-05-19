# Refreshes the TikTok Shop access token when it's within the 5-minute expiry
# window. Mirrors Tiktok::TokenService — same lock pattern via Redis::LockManager
# to prevent concurrent refresh storms when multiple jobs hit the API at once.
class Tiktok::Shop::TokenService
  pattr_initialize [:channel!]

  def access_token
    return current_access_token if token_valid?
    return refresh_access_token if refresh_token_valid?

    channel.prompt_reauthorization! unless channel.reauthorization_required?
    current_access_token
  end

  private

  def current_access_token
    channel.access_token
  end

  def token_valid?
    return false if channel.access_token_expires_at.blank?

    5.minutes.from_now < channel.access_token_expires_at
  end

  def refresh_token_valid?
    return false if channel.refresh_token_expires_at.blank?

    Time.current < channel.refresh_token_expires_at
  end

  def refresh_access_token
    lock_manager = Redis::LockManager.new
    begin
      # Another worker is mid-refresh; trust them and return the current token,
      # which is valid for at least the 5-minute buffer window.
      return current_access_token unless lock_manager.lock(lock_key, 30.seconds)

      result = Tiktok::Shop::AuthClient.renew_short_term_access_token(channel.refresh_token, region: channel.region)
      channel.update!(
        access_token: result[:access_token],
        refresh_token: result[:refresh_token],
        access_token_expires_at: result[:access_token_expires_at],
        refresh_token_expires_at: result[:refresh_token_expires_at]
      )

      lock_manager.unlock(lock_key)
      result[:access_token]
    rescue StandardError => e
      lock_manager.unlock(lock_key)
      raise e
    end
  end

  def lock_key
    "tiktok_shop:refresh_token_mutex:channel_#{channel.id}"
  end
end
