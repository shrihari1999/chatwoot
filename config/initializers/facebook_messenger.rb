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

# Extend the facebook-messenger gem to support the message_edit event type,
# which is not included in the gem's built-in EVENTS. This must run before
# the reloader block so the event type is available when hooks are registered.
#
# Extends the frozen gem constants once at boot time. The `unless` guard
# prevents re-initialization warnings on Spring/Zeitwerk reloads.
unless Facebook::Messenger::Incoming::EVENTS.key?('message_edit')
  module Facebook
    module Messenger
      module Incoming
        # Minimal incoming class for message_edit webhook events.
        # Payload structure:
        #   { "sender" => {"id" => PSID}, "recipient" => {"id" => PAGE_ID},
        #     "message_edit" => {"mid" => MESSAGE_ID, "text" => NEW_TEXT, "num_edit" => N} }
        class MessageEdit
          include Facebook::Messenger::Incoming::Common

          def id
            @messaging['message_edit']['mid']
          end

          def text
            @messaging['message_edit']['text']
          end
        end

        # Monkey-patch EVENTS to include message_edit so Incoming.parse can route it.
        # The gem freezes the original EVENTS hash, so we rebuild and reassign the constant.
        _new_incoming_events = EVENTS.merge('message_edit' => MessageEdit).freeze
        remove_const(:EVENTS)
        const_set(:EVENTS, _new_incoming_events)
      end

      module Bot
        # Monkey-patch Bot::EVENTS so Bot.on :message_edit is accepted.
        # The gem freezes the original EVENTS array, so we rebuild and reassign the constant.
        _new_bot_events = (EVENTS + %i[message_edit]).freeze
        remove_const(:EVENTS)
        const_set(:EVENTS, _new_bot_events)
      end
    end
  end
end

unless Facebook::Messenger::Incoming::EVENTS.key?('message_reaction')
  module Facebook
    module Messenger
      module Incoming
        # Minimal incoming class for message_reaction webhook events.
        # Payload structure:
        #   { "sender" => {"id" => PSID}, "recipient" => {"id" => PAGE_ID},
        #     "reaction" => {"reaction" => REACTION_TYPE, "emoji" => EMOJI,
        #                     "action" => "react"|"unreact", "mid" => MESSAGE_ID} }
        class MessageReaction
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

        # Monkey-patch EVENTS to include message_reaction so Incoming.parse can route it.
        # The gem freezes the original EVENTS hash, so we rebuild and reassign the constant.
        _new_incoming_events = EVENTS.merge('message_reaction' => MessageReaction).freeze
        remove_const(:EVENTS)
        const_set(:EVENTS, _new_incoming_events)
      end

      module Bot
        # Monkey-patch Bot::EVENTS so Bot.on :message_reaction is accepted.
        # The gem freezes the original EVENTS array, so we rebuild and reassign the constant.
        _new_bot_events = (EVENTS + %i[message_reaction]).freeze
        remove_const(:EVENTS)
        const_set(:EVENTS, _new_bot_events)
      end
    end
  end
end

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
