# This class creates both outgoing messages from chatwoot and echo outgoing messages based on the flag `outgoing_echo`
# Assumptions
# 1. Incase of an outgoing message which is echo, source_id will NOT be nil,
#    based on this we are showing "not sent from chatwoot" message in frontend
#    Hence there is no need to set user_id in message for outgoing echo messages.

class Messages::Facebook::MessageBuilder < Messages::Messenger::MessageBuilder
  attr_reader :response

  def initialize(response, inbox, outgoing_echo: false)
    super()
    @response = response
    @inbox = inbox
    @outgoing_echo = outgoing_echo
    @sender_id = (@outgoing_echo ? @response.recipient_id : @response.sender_id)
    @message_type = (@outgoing_echo ? :outgoing : :incoming)
    @attachments = (@response.attachments || [])
  end

  def perform
    # This channel might require reauthorization, may be owner might have changed the fb password
    return if @inbox.channel.reauthorization_required?

    ActiveRecord::Base.transaction do
      build_contact_inbox
      build_message
    end
  rescue Koala::Facebook::AuthenticationError => e
    Rails.logger.warn("Facebook authentication error for inbox: #{@inbox.id} with error: #{e.message}")
    Rails.logger.error e
    @inbox.channel.authorization_error!
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: @inbox.account).capture_exception
    true
  end

  private

  def build_contact_inbox
    @contact_inbox = ::ContactInboxWithContactBuilder.new(
      source_id: @sender_id,
      inbox: @inbox,
      contact_attributes: contact_params
    ).perform
    heal_fallback_name
  end

  # ContactInboxWithContactBuilder only names a contact at creation time. A contact created
  # while the profile lookup was failing would otherwise keep the fallback name forever, even
  # once we can resolve the real one.
  def heal_fallback_name
    contact = @contact_inbox.contact
    return unless contact.name == Facebook::UserProfileService::FALLBACK_NAME

    resolved_name = contact_params[:name]
    return if resolved_name.blank? || resolved_name == Facebook::UserProfileService::FALLBACK_NAME

    contact.update!(name: resolved_name)
  end

  def build_message
    @message = conversation.messages.create!(message_params)

    @attachments.each do |attachment|
      process_attachment(attachment)
    end
  end

  def conversation
    @conversation ||= set_conversation_based_on_inbox_config
  end

  def set_conversation_based_on_inbox_config
    if @inbox.lock_to_single_conversation
      Conversation.where(conversation_params).order(created_at: :desc).first || build_conversation
    else
      find_or_build_for_multiple_conversations
    end
  end

  def find_or_build_for_multiple_conversations
    # If lock to single conversation is disabled, we will create a new conversation if previous conversation is resolved
    last_conversation = Conversation.where(conversation_params).where.not(status: :resolved).order(created_at: :desc).first
    return build_conversation if last_conversation.nil?

    last_conversation
  end

  def build_conversation
    Conversation.create!(conversation_params.merge(
                           contact_inbox_id: @contact_inbox.id,
                           created_by_outgoing_echo: @outgoing_echo
                         ))
  end

  def location_params(attachment)
    lat = attachment['payload']['coordinates']['lat']
    long = attachment['payload']['coordinates']['long']
    {
      external_url: attachment['url'],
      coordinates_lat: lat,
      coordinates_long: long,
      fallback_title: attachment['title']
    }
  end

  def fallback_params(attachment)
    {
      fallback_title: attachment['title'] || attachment.dig('payload', 'title'),
      external_url: attachment['url'] || attachment.dig('payload', 'url')
    }
  end

  # Facebook shared posts point to page URLs, not downloadable media URLs.
  # Both `share` and `post` attachment types carry a page URL rather than a media file,
  # so map them to `fallback` (which keeps the title/link without attempting a download).
  # Keep this Facebook-only so Messenger/Instagram share attachments still use the parent media handling.
  def normalize_file_type(type)
    return :fallback if [:share, :post].include?(type.to_sym)

    super
  end

  def conversation_params
    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact_inbox.contact_id
    }
  end

  def message_params
    content_attributes = {
      in_reply_to_external_id: response.in_reply_to_external_id
    }
    content_attributes[:external_echo] = true if @outgoing_echo

    {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: @message_type,
      status: @outgoing_echo ? :delivered : :sent,
      content: response.content,
      source_id: response.identifier,
      content_attributes: content_attributes,
      sender: @outgoing_echo ? nil : @contact_inbox.contact
    }
  end

  def contact_params
    @contact_params ||= build_contact_params
  end

  def build_contact_params
    return { account_id: @inbox.account_id } unless profile_fetch_required?

    profile = Facebook::UserProfileService.new(channel: @inbox.channel, source_id: @sender_id).perform
    {
      name: profile[:name].presence || Facebook::UserProfileService::FALLBACK_NAME,
      account_id: @inbox.account_id,
      avatar_url: profile[:avatar_url]
    }
  end

  # The profile of a contact we have already named cannot change here, so skip the Graph
  # round trip on every subsequent message from them.
  def profile_fetch_required?
    name = existing_contact&.name
    name.blank? || name == Facebook::UserProfileService::FALLBACK_NAME
  end

  def existing_contact
    return @existing_contact if defined?(@existing_contact)

    @existing_contact = @inbox.contact_inboxes.find_by(source_id: @sender_id)&.contact
  end
end
