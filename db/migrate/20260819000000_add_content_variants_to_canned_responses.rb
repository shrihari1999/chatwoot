class AddContentVariantsToCannedResponses < ActiveRecord::Migration[7.1]
  def up
    add_column :canned_responses, :content_variants, :jsonb, default: [], null: false
    add_column :canned_responses, :content_variant_cursor, :integer, default: 0, null: false
  end

  def down
    remove_column :canned_responses, :content_variants
    remove_column :canned_responses, :content_variant_cursor
  end
end
