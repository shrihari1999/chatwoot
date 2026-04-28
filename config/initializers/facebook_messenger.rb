# ref: https://github.com/jgorset/facebook-messenger#make-a-configuration-provider
class ChatwootFbProvider < Facebook::Messenger::Configuration::Providers::Base
  def valid_verify_token?(_verify_token)
    GlobalConfigService.load('FB_VERIFY_TOKEN', '')
  end

  def app_secret_for(_page_id)
    GlobalConfigService.load('FB_APP_SECRET', '')
  end

  def access_token_for(page_id)
    Channel::FacebookPage.where(page_id: page_id).last.page_access_token
  end

  private

  def bot
    Chatwoot::Bot
  end
end

# Extends the facebook-messenger gem with custom event types not built into the gem
# (e.g. message_edit, message_reaction). The gem freezes its EVENTS constants, so we
# rebuild and reassign them once at boot. The `unless` guard prevents re-initialization
# warnings on Spring/Zeitwerk reloads.
def register_facebook_messenger_event(name, klass)
  return if Facebook::Messenger::Incoming::EVENTS.key?(name)

  new_incoming = Facebook::Messenger::Incoming::EVENTS.merge(name => klass).freeze
  Facebook::Messenger::Incoming.send(:remove_const, :EVENTS)
  Facebook::Messenger::Incoming.const_set(:EVENTS, new_incoming)

  new_bot = (Facebook::Messenger::Bot::EVENTS + [name.to_sym]).freeze
  Facebook::Messenger::Bot.send(:remove_const, :EVENTS)
  Facebook::Messenger::Bot.const_set(:EVENTS, new_bot)
end

# rubocop:disable Style/OneClassPerFile
# Defining two tiny gem-extension classes side-by-side keeps the related
# monkey-patches together rather than spread across multiple initializer files.

# Minimal incoming class for message_edit webhook events.
# Payload structure:
#   { "sender" => {"id" => PSID}, "recipient" => {"id" => PAGE_ID},
#     "message_edit" => {"mid" => MESSAGE_ID, "text" => NEW_TEXT, "num_edit" => N} }
class Facebook::Messenger::Incoming::MessageEdit
  include Facebook::Messenger::Incoming::Common

  def id
    @messaging['message_edit']['mid']
  end

  def text
    @messaging['message_edit']['text']
  end
end

# Minimal incoming class for message_reaction webhook events.
# Payload structure:
#   { "sender" => {"id" => PSID}, "recipient" => {"id" => PAGE_ID},
#     "reaction" => {"reaction" => REACTION_TYPE, "emoji" => EMOJI,
#                     "action" => "react"|"unreact", "mid" => MESSAGE_ID} }
class Facebook::Messenger::Incoming::MessageReaction
  include Facebook::Messenger::Incoming::Common

  def reaction
    @messaging['reaction']['reaction']
  end

  def emoji
    @messaging['reaction']['emoji']
  end

  def action
    @messaging['reaction']['action']
  end

  def mid
    @messaging['reaction']['mid']
  end
end
# rubocop:enable Style/OneClassPerFile

register_facebook_messenger_event('message_edit', Facebook::Messenger::Incoming::MessageEdit)
register_facebook_messenger_event('message_reaction', Facebook::Messenger::Incoming::MessageReaction)

Rails.application.reloader.to_prepare do
  Facebook::Messenger.configure do |config|
    config.provider = ChatwootFbProvider.new
  end

  Facebook::Messenger::Bot.on :message do |message|
    Webhooks::FacebookEventsJob.perform_later(message.to_json)
  end

  Facebook::Messenger::Bot.on :delivery do |delivery|
    Rails.logger.info "Recieved delivery status #{delivery.to_json}"
    Webhooks::FacebookDeliveryJob.perform_later(delivery.to_json)
  end

  Facebook::Messenger::Bot.on :read do |read|
    Rails.logger.info "Recieved read status  #{read.to_json}"
    Webhooks::FacebookDeliveryJob.perform_later(read.to_json)
  end

  Facebook::Messenger::Bot.on :message_echo do |message|
    # Add delay to prevent race condition where echo arrives before send message API completes
    # This avoids duplicate messages when echo comes early during API processing
    Webhooks::FacebookEventsJob.set(wait: 2.seconds).perform_later(message.to_json)
  end

  Facebook::Messenger::Bot.on :message_edit do |message_edit|
    # Wait slightly longer than the 2-second delay used for incoming messages above
    # to absorb the race where an edit webhook arrives before the original message
    # has been persisted by FacebookEventsJob.
    Webhooks::FacebookMessageEditJob.set(wait: 3.seconds).perform_later(message_edit.to_json)
  end

  Facebook::Messenger::Bot.on :message_reaction do |reaction|
    Webhooks::FacebookReactionJob.set(wait: 3.seconds).perform_later(reaction.to_json)
  end
end
