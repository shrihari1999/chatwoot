class Webhooks::LazadaEventsJob < ApplicationJob
  queue_as :default

  def perform(params: {}, post_body: '', signature: '')
    @params = params.with_indifferent_access
    return unless valid_channel?
    return unless valid_signature?(post_body, signature)
    
    if im_message?
      Lazada::IncomingMessageService.new(inbox: @channel.inbox, params: @params).perform
    elsif session_update?
      Lazada::SessionUpdateService.new(inbox: @channel.inbox, params: @params).perform
    end
  end

  private

  def valid_channel?
    @channel = Channel::Lazada.find_by(shop_id: @params[:seller_id].to_s)
    @channel.present? && @channel.account&.active?
  end

  def valid_signature?(post_body, signature)
    return false if signature.blank? || post_body.blank?

    base = @channel.app_key + post_body
    expected = OpenSSL::HMAC.hexdigest('SHA256', @channel.app_secret, base).upcase
    ActiveSupport::SecurityUtils.secure_compare(expected, signature.upcase)
  end

  def im_message?
    @params[:message_type].to_i == 2
  end

  def session_update?
    @params[:sync_type] == 'SESSION_UPDATE'
  end
end
