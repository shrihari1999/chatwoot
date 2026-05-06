class MakeCannedResponseCategoryRequired < ActiveRecord::Migration[7.0]
  def up
    # Wipe both tables — the Freshchat sync repopulates from scratch.
    # Raw SQL bypasses callbacks/validations; orphan ActiveStorage blobs
    # (canned response attachments) are negligible in scale.
    execute 'DELETE FROM active_storage_attachments WHERE record_type = \'CannedResponse\''
    execute 'DELETE FROM canned_responses'
    execute 'DELETE FROM canned_response_categories'

    change_column_null :canned_responses, :category_id, false
    add_foreign_key :canned_responses, :canned_response_categories,
                    column: :category_id, on_delete: :restrict
    add_index :canned_responses,
              [:account_id, :category_id, :short_code],
              unique: true,
              name: 'idx_canned_responses_unique_per_category'
  end

  def down
    remove_index :canned_responses, name: 'idx_canned_responses_unique_per_category'
    remove_foreign_key :canned_responses, column: :category_id
    change_column_null :canned_responses, :category_id, true
  end
end
