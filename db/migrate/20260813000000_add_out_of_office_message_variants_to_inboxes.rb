class AddOutOfOfficeMessageVariantsToInboxes < ActiveRecord::Migration[7.1]
  def up
    add_column :inboxes, :out_of_office_message_variants, :jsonb, default: [], null: false
    add_column :inboxes, :out_of_office_variant_cursor, :integer, default: 0, null: false

    seed_variants_for_instagram_inboxes
  end

  def down
    remove_column :inboxes, :out_of_office_message_variants
    remove_column :inboxes, :out_of_office_variant_cursor
  end

  private

  # Instagram inboxes rotate through several wordings of the same out-of-office
  # notice so a returning customer does not receive a byte-identical auto-reply
  # every time -- IG's anti-spam heuristics penalise that. Seeding the extra
  # slots with the message already in use keeps behaviour unchanged until
  # someone edits them in the inbox settings.
  def seed_variants_for_instagram_inboxes
    # The Inbox model may have cached its columns before the add_column above.
    Inbox.reset_column_information

    Inbox.where(channel_type: 'Channel::Instagram')
         .where.not(out_of_office_message: [nil, ''])
         .find_each do |inbox|
      next if inbox.out_of_office_message_variants.present?

      copies = Array.new(Inbox::OUT_OF_OFFICE_MESSAGE_VARIANTS_LIMIT, inbox.out_of_office_message)
      inbox.update_columns(out_of_office_message_variants: copies) # rubocop:disable Rails/SkipsModelValidations
    end
  end
end
