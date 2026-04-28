# frozen_string_literal: true

class Integrations::Facebook::MessageCreator
  attr_reader :response

  def initialize(response)
    @response = response
  end

  def perform
    # begin
    if response.deleted?
      handle_delete_event
    elsif agent_message_via_echo?
      create_agent_message
    else
      create_contact_message
    end
    # rescue => e
    # ChatwootExceptionTracker.new(e).capture_exception
    # end
  end

  private

  def agent_message_via_echo?
    # TODO : check and remove send_from_chatwoot_app if not working
    response.echo? && !response.sent_from_chatwoot_app?
    # this means that it is an agent message from page, but not sent from chatwoot.
    # User can send from fb page directly on mobile / web messenger, so this case should be handled as agent message
  end

  def each_recipient_inbox
    Channel::FacebookPage.where(page_id: response.recipient_id).each { |page| yield page.inbox }
  end

  def create_agent_message
    Channel::FacebookPage.where(page_id: response.sender_id).each do |page|
      mb = Messages::Facebook::MessageBuilder.new(response, page.inbox, outgoing_echo: true)
      mb.perform
    end
  end

  def create_contact_message
    each_recipient_inbox do |inbox|
      Messages::Facebook::MessageBuilder.new(response, inbox).perform
    end
  end

  def handle_delete_event
    each_recipient_inbox do |inbox|
      Facebook::IncomingDeleteService.new(inbox: inbox, response: response).perform
    end
  end
end
