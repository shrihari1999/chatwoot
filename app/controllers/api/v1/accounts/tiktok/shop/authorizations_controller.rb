class Api::V1::Accounts::Tiktok::Shop::AuthorizationsController < Api::V1::Accounts::OauthAuthorizationController
  include Tiktok::Shop::IntegrationHelper

  def create
    redirect_url = Tiktok::Shop::AuthClient.authorize_url(
      state: generate_tiktok_shop_token(Current.account.id)
    )

    if redirect_url
      render json: { success: true, url: redirect_url }
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end
end
