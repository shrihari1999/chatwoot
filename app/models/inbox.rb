# frozen_string_literal: true

# == Schema Information
#
# Table name: inboxes
#
#  id                            :integer          not null, primary key
#  allow_messages_after_resolved :boolean          default(TRUE)
#  auto_assignment_config        :jsonb
#  business_name                 :string
#  channel_type                  :string
#  csat_config                   :jsonb            not null
#  csat_survey_enabled           :boolean          default(FALSE)
#  email_address                 :string
#  enable_auto_assignment        :boolean          default(TRUE)
#  enable_email_collect          :boolean          default(TRUE)
#  greeting_enabled              :boolean          default(FALSE)
#  greeting_message              :string
#  lock_to_single_conversation   :boolean          default(FALSE), not null
#  name                          :string           not null
#  out_of_office_message         :string
#  out_of_office_message_variants :jsonb           not null
#  out_of_office_variant_cursor  :integer          default(0), not null
#  sender_name_type              :integer          default("friendly"), not null
#  timezone                      :string           default("UTC")
#  working_hours_enabled         :boolean          default(FALSE)
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  account_id                    :integer          not null
#  channel_id                    :integer          not null
#  portal_id                     :bigint
#
# Indexes
#
#  index_inboxes_on_account_id                   (account_id)
#  index_inboxes_on_channel_id_and_channel_type  (channel_id,channel_type)
#  index_inboxes_on_portal_id                    (portal_id)
#
# Foreign Keys
#
#  fk_rails_...  (portal_id => portals.id)
#

class Inbox < ApplicationRecord
  include Reportable
  include Avatarable
  include OutOfOffisable
  include AccountCacheRevalidator
  include InboxAgentAvailability
  include InboxBrandedEmailLayoutable

  # Extra out-of-office wordings an Instagram inbox cycles through, on top of
  # the one in out_of_office_message. Four total is what the settings UI renders.
  OUT_OF_OFFICE_MESSAGE_VARIANTS_LIMIT = 3

  # Not allowing characters:
  validates :name, presence: true
  validates :account_id, presence: true
  validates :timezone, inclusion: { in: TZInfo::Timezone.all_identifiers }
  validates :out_of_office_message, length: { maximum: Limits::OUT_OF_OFFICE_MESSAGE_MAX_LENGTH }
  validates :greeting_message, length: { maximum: Limits::GREETING_MESSAGE_MAX_LENGTH }
  validate :ensure_valid_max_assignment_limit
  validate :ensure_valid_out_of_office_message_variants

  belongs_to :account
  belongs_to :portal, optional: true

  belongs_to :channel, polymorphic: true, dependent: :destroy

  has_many :campaigns, dependent: :destroy_async
  has_many :contact_inboxes, dependent: :destroy_async
  has_many :contacts, through: :contact_inboxes

  has_many :inbox_members, dependent: :destroy_async
  has_many :members, through: :inbox_members, source: :user
  has_many :conversations, dependent: :destroy_async
  has_many :messages, dependent: :destroy_async
  has_many :email_templates, dependent: :destroy_async

  has_one :inbox_assignment_policy, dependent: :destroy
  has_one :assignment_policy, through: :inbox_assignment_policy
  has_one :agent_bot_inbox, dependent: :destroy_async
  has_one :agent_bot, through: :agent_bot_inbox
  has_many :webhooks, dependent: :destroy_async
  has_many :hooks, dependent: :destroy_async, class_name: 'Integrations::Hook'

  enum sender_name_type: { friendly: 0, professional: 1 }

  before_destroy :capture_filtered_unread_count_user_ids, prepend: true
  after_destroy :delete_round_robin_agents

  after_create_commit :dispatch_create_event
  after_update_commit :dispatch_update_event
  after_destroy_commit :invalidate_filtered_unread_counts_after_destroy

  scope :order_by_name, -> { order('lower(name) ASC') }

  # Adds multiple members to the inbox
  # @param user_ids [Array<Integer>] Array of user IDs to add as members
  # @return [void]
  def add_members(user_ids)
    inbox_members.create!(user_ids.map { |user_id| { user_id: user_id } })
    update_account_cache
  end

  # Removes multiple members from the inbox
  # @param user_ids [Array<Integer>] Array of user IDs to remove
  # @return [void]
  def remove_members(user_ids)
    inbox_members.where(user_id: user_ids).destroy_all
    update_account_cache
  end

  # Sanitizes inbox name for balanced email provider compatibility
  # ALLOWS: /'._- and Unicode letters/numbers/emojis
  # REMOVES: Forbidden chars (\<>@"()) + spam-trigger symbols (!#$%&*+=?^`{|}~)
  def sanitized_name
    return default_name_for_blank_name if name.blank?

    sanitized = apply_sanitization_rules(name)
    sanitized.blank? && email? ? display_name_from_email : sanitized
  end

  def sanitized_business_name
    sanitize_raw_name(business_name) || sanitized_name
  end

  def sms?
    channel_type == 'Channel::Sms'
  end

  def facebook?
    channel_type == 'Channel::FacebookPage'
  end

  def instagram?
    (facebook? || instagram_direct?) && channel.instagram_id.present?
  end

  def instagram_direct?
    channel_type == 'Channel::Instagram'
  end

  def tiktok?
    channel_type == 'Channel::Tiktok'
  end

  def tiktok_shop?
    channel_type == 'Channel::TiktokShop'
  end

  def web_widget?
    channel_type == 'Channel::WebWidget'
  end

  def api?
    channel_type == 'Channel::Api'
  end

  def email?
    channel_type == 'Channel::Email'
  end

  def twilio?
    channel_type == 'Channel::TwilioSms'
  end

  def twitter?
    channel_type == 'Channel::TwitterProfile'
  end

  def telegram?
    channel_type == 'Channel::Telegram'
  end

  def lazada?
    channel_type == 'Channel::Lazada'
  end

  def whatsapp?
    channel_type == 'Channel::Whatsapp'
  end

  def twilio_whatsapp?
    channel_type == 'Channel::TwilioSms' && channel.medium == 'whatsapp'
  end

  # Every out-of-office wording this inbox may send, in cycle order. Only
  # Instagram inboxes rotate; every other channel keeps sending the single
  # out_of_office_message it always has.
  def out_of_office_messages
    return [out_of_office_message].compact_blank unless instagram_direct?

    [out_of_office_message, *out_of_office_message_variants].compact_blank
  end

  # Draws the next wording and advances the cursor, so consecutive auto-replies
  # walk the list linearly (1 -> 2 -> 3 -> 4 -> 1) instead of repeating. The row
  # lock keeps two simultaneous sends from drawing the same entry. update_column
  # deliberately skips dispatch_update_event -- moving the cursor is bookkeeping,
  # not a settings change worth broadcasting to every open dashboard.
  def next_out_of_office_message
    messages = out_of_office_messages
    return messages.first if messages.size <= 1

    with_lock do
      messages = out_of_office_messages
      index = out_of_office_variant_cursor % messages.size
      update_column(:out_of_office_variant_cursor, (index + 1) % messages.size) # rubocop:disable Rails/SkipsModelValidations
      messages[index]
    end
  end

  def assignable_agents
    (account.users.where(id: members.select(:user_id)) + account.administrators).uniq
  end

  def active_bot?
    agent_bot_inbox&.active? || hooks.where(app_id: %w[dialogflow],
                                            status: 'enabled').count.positive?
  end

  def inbox_type
    channel.name
  end

  def webhook_data
    {
      id: id,
      name: name
    }
  end

  def callback_webhook_url
    case channel_type
    when 'Channel::TwilioSms'
      "#{ENV.fetch('FRONTEND_URL', nil)}/twilio/callback"
    when 'Channel::Sms'
      "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/sms/#{channel.phone_number.delete_prefix('+')}"
    when 'Channel::Line'
      "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/line/#{channel.line_channel_id}"
    when 'Channel::Whatsapp'
      "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/whatsapp/#{channel.phone_number}"
    when 'Channel::Lazada'
      "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/lazada/#{channel.shop_id}"
    when 'Channel::TiktokShop'
      "#{ENV.fetch('FRONTEND_URL', nil)}/webhooks/tiktok_shop"
    end
  end

  def member_ids_with_assignment_capacity
    members.ids
  end

  def auto_assignment_v2_enabled?
    account.feature_enabled?('assignment_v2')
  end

  # Callers (Reauthorizable) only invoke this on a real transition, so the previous
  # value is always the inverse of the new boolean value.
  def dispatch_reauthorization_event(reauthorization_required)
    return if ENV['ENABLE_INBOX_EVENTS'].blank?

    changed_attributes = { reauthorization_required: [!reauthorization_required, reauthorization_required] }
    Rails.configuration.dispatcher.dispatch(INBOX_UPDATED, Time.zone.now, inbox: self, changed_attributes: changed_attributes)
  end

  private

  def default_name_for_blank_name
    email? ? display_name_from_email : ''
  end

  def sanitize_raw_name(raw)
    return nil if raw.blank?

    result = apply_sanitization_rules(raw)
    result.presence
  end

  def apply_sanitization_rules(name)
    name.gsub(/[\\<>@"!#$%&*+=?^`{|}~:;()]/, '')        # Remove forbidden chars
        .gsub(/[\x00-\x1F\x7F]/, ' ')                   # Replace control chars with spaces
        .gsub(/\A[[:punct:]]+|[[:punct:]]+\z/, '')      # Remove leading/trailing punctuation
        .gsub(/\s+/, ' ')                               # Normalize spaces
        .strip
  end

  def display_name_from_email
    channel.email.split('@').first.parameterize.titleize
  end

  def dispatch_create_event
    return if ENV['ENABLE_INBOX_EVENTS'].blank?

    Rails.configuration.dispatcher.dispatch(INBOX_CREATED, Time.zone.now, inbox: self)
  end

  def dispatch_update_event
    return if ENV['ENABLE_INBOX_EVENTS'].blank?

    Rails.configuration.dispatcher.dispatch(INBOX_UPDATED, Time.zone.now, inbox: self, changed_attributes: previous_changes)
  end

  def ensure_valid_max_assignment_limit
    # overridden in enterprise/app/models/enterprise/inbox.rb
  end

  def ensure_valid_out_of_office_message_variants
    variants = out_of_office_message_variants
    return if variants.blank?

    unless variants.is_a?(Array) && variants.all?(String)
      errors.add(:out_of_office_message_variants, 'must be a list of messages')
      return
    end

    errors.add(:out_of_office_message_variants, "cannot hold more than #{OUT_OF_OFFICE_MESSAGE_VARIANTS_LIMIT} messages") if
      variants.size > OUT_OF_OFFICE_MESSAGE_VARIANTS_LIMIT

    errors.add(:out_of_office_message_variants, 'has a message that is too long') if
      variants.any? { |variant| variant.length > Limits::OUT_OF_OFFICE_MESSAGE_MAX_LENGTH }
  end

  def delete_round_robin_agents
    ::AutoAssignment::InboxRoundRobinService.new(inbox: self).clear_queue
  end

  def capture_filtered_unread_count_user_ids
    return if account.blank?

    @filtered_unread_count_user_ids = (inbox_members.pluck(:user_id) + account.account_users.administrator.pluck(:user_id)).uniq
  end

  def invalidate_filtered_unread_counts_after_destroy
    invalidator = ::Conversations::UnreadCounts::FilteredCountInvalidator.new(account)
    invalidator.conversation_changed!
    invalidator.users_visibility_changed!(user_ids: @filtered_unread_count_user_ids)
  end

  def check_channel_type?
    ['Channel::Email', 'Channel::Api', 'Channel::WebWidget'].include?(channel_type)
  end
end

Inbox.prepend_mod_with('Inbox')
Inbox.include_mod_with('Audit::Inbox')
Inbox.include_mod_with('Concerns::Inbox')
