class Instagram::WebhooksBaseService
  attr_reader :channel

  def initialize(channel)
    @channel = channel
  end

  private

  def inbox_channel(_instagram_id)
    @inbox = ::Inbox.find_by(channel: @channel)
  end

  def find_or_create_contact(user)
    @contact_inbox = @inbox.contact_inboxes.where(source_id: user['id']).first
    @contact = @contact_inbox.contact if @contact_inbox

    update_instagram_profile_link(user) && return if @contact

    # Fallback: if no ContactInbox was found for the numeric IGSID, look for
    # an existing Contact on this account whose `social_instagram_user_name`
    # matches the incoming sender's @handle (populated by the Freshchat
    # importer for historical archives, or by prior Chatwoot activity).
    # This links live-first messages to imported historical Contacts so the
    # customer has a single unified Contact instead of a duplicate.
    if (existing = find_contact_by_ig_handle(user['username']))
      link_existing_contact_to_new_ig_scope(existing, user)
      return
    end

    @contact_inbox = @inbox.channel.create_contact_inbox(
      user['id'], contact_name(user)
    )

    @contact = @contact_inbox.contact
    update_instagram_profile_link(user)
    Avatar::AvatarFromUrlJob.perform_later(@contact, user['profile_pic']) if user['profile_pic']
  end

  # Match on lowercased social_instagram_user_name (case-insensitive) across
  # the whole account. Prefer contacts tagged with `freshchat_customer_id`
  # (imported archives) so the imported history is picked over any stray
  # older test contact if both exist.
  def find_contact_by_ig_handle(username)
    handle = username.to_s.downcase.strip
    return nil if handle.empty?

    matches = @inbox.account.contacts
                    .where("contacts.additional_attributes ? 'social_instagram_user_name'")
                    .where("LOWER(contacts.additional_attributes->>'social_instagram_user_name') = ?", handle)
    matches.where("contacts.additional_attributes ? 'freshchat_customer_id'").first || matches.first
  end

  def link_existing_contact_to_new_ig_scope(existing_contact, user)
    @contact = existing_contact
    @contact_inbox = ContactInbox.find_or_create_by!(
      inbox: @inbox, contact: existing_contact, source_id: user['id']
    )
    update_instagram_profile_link(user)
    Avatar::AvatarFromUrlJob.perform_later(@contact, user['profile_pic']) if user['profile_pic']
    Rails.logger.info(
      "[Instagram::WebhooksBaseService] linked incoming IGSID=#{user['id']} " \
      "to existing contact id=#{existing_contact.id} via handle=@#{user['username']}"
    )
  end

  # Instagram omits `name` for users who never set a display name, returning only the handle.
  # Without this fallback ContactInboxWithContactBuilder invents a random name and the agent
  # sees "purple-resonance-890" instead of the customer's @username.
  def contact_name(user)
    user['name'].presence || user['username']
  end

  def update_instagram_profile_link(user)
    return unless user['username']

    instagram_attributes = build_instagram_attributes(user)
    @contact.update!(additional_attributes: @contact.additional_attributes.merge(instagram_attributes))
  end

  def build_instagram_attributes(user)
    attributes = {
      # TODO: Remove this once we show the social_instagram_user_name in the UI instead of the username
      'social_profiles': { 'instagram': user['username'] },
      'social_instagram_user_name': user['username']
    }

    # Add optional attributes if present
    optional_fields = %w[
      follower_count
      is_user_follow_business
      is_business_follow_user
      is_verified_user
    ]

    optional_fields.each do |field|
      next if user[field].nil?

      attributes["social_instagram_#{field}"] = user[field]
    end

    attributes
  end
end
