#######################################
# To create an external channel reply service
# - Inherit this as the base class.
# - Implement `channel_class` method in your child class.
# - Implement `perform_reply` method in your child class.
# - Implement additional custom logic for your `perform_reply` method.
# - When required override the validation_methods.
# - Use Childclass.new.perform.
######################################
class Base::SendOnChannelService
  pattr_initialize [:message!]

  def perform
    validate_target_channel
    return unless outgoing_message?
    return if invalid_message?

    perform_reply
  end

  private

  delegate :conversation, to: :message
  delegate :contact, :contact_inbox, :inbox, to: :conversation
  delegate :channel, to: :inbox

  def channel_class
    raise 'Overwrite this method in child class'
  end

  def perform_reply
    raise 'Overwrite this method in child class'
  end

  # Platform recipient id for replies. The conversation's own contact_inbox is
  # the thread being replied to — a contact can hold multiple contact_inboxes
  # on one inbox (Freshchat-imported archive + live), and Contact#get_source_id
  # returns an arbitrary one. Freshchat placeholder ids are unroutable, so when
  # the conversation hangs off an imported archive, fall back to the contact's
  # real platform id on the same inbox (created by the live webhook handler).
  def recipient_source_id
    source_id = contact_inbox&.source_id
    return source_id unless source_id&.start_with?('freshchat-customer-')

    contact.contact_inboxes
           .where(inbox_id: inbox.id)
           .where.not('source_id LIKE ?', 'freshchat-customer-%')
           .order(:id)
           .pick(:source_id) || source_id
  end

  def outgoing_message_originated_from_channel?
    # TODO: we need to refactor this logic as more integrations comes by
    # chatwoot messages won't have source id at the moment
    # TODO: migrate source_ids to external_source_ids and check the source id relevant to specific channel
    message.source_id.present?
  end

  def outgoing_message?
    message.outgoing? || message.template?
  end

  def invalid_message?
    # private notes aren't send to the channels
    # we should also avoid the case of message loops, when outgoing messages are created from channel
    # voice_call bubbles are call status indicators, not deliverable messages
    message.private? || outgoing_message_originated_from_channel? || message.content_type == 'voice_call'
  end

  def validate_target_channel
    raise 'Invalid channel service was called' if inbox.channel.class != channel_class
  end
end
