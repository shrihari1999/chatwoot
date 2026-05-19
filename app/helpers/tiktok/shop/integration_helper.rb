# JWT helpers for the TikTok Shop OAuth state parameter. Mirrors
# Tiktok::IntegrationHelper but signs with the Shop app_secret instead of the
# Business Messaging app_secret so the two systems can never confuse each other.
module Tiktok::Shop::IntegrationHelper
  def generate_tiktok_shop_token(account_id)
    return if shop_client_secret.blank?

    JWT.encode(shop_token_payload(account_id), shop_client_secret, 'HS256')
  rescue StandardError => e
    Rails.logger.error("Failed to generate TikTok Shop token: #{e.message}")
    nil
  end

  def verify_tiktok_shop_token(token)
    return if token.blank? || shop_client_secret.blank?

    decode_shop_token(token, shop_client_secret)
  end

  private

  def shop_client_secret
    @shop_client_secret ||= GlobalConfigService.load('TIKTOK_SHOP_APP_SECRET', nil)
  end

  def shop_token_payload(account_id)
    {
      sub: account_id,
      iat: Time.current.to_i
    }
  end

  def decode_shop_token(token, secret)
    JWT.decode(token, secret, true, { algorithm: 'HS256', verify_expiration: true }).first['sub']
  rescue StandardError => e
    Rails.logger.error("Unexpected error verifying TikTok Shop token: #{e.message}")
    nil
  end
end
