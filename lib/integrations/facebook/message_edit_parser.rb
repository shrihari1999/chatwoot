# frozen_string_literal: true

# Parses the raw JSON payload from a Facebook Messenger message_edit webhook event.
# Payload structure:
#   { "sender" => {"id" => PSID}, "recipient" => {"id" => PAGE_ID},
#     "message_edit" => {"mid" => MESSAGE_ID, "text" => NEW_TEXT, "num_edit" => N} }
class Integrations::Facebook::MessageEditParser
  def initialize(response_json)
    @messaging = JSON.parse(response_json)
  end

  def sender_id
    @messaging.dig('sender', 'id')
  end

  def recipient_id
    @messaging.dig('recipient', 'id')
  end

  def identifier
    @messaging.dig('message_edit', 'mid')
  end

  def content
    @messaging.dig('message_edit', 'text')
  end
end
