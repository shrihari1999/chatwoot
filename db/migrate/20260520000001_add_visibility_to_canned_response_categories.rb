class AddVisibilityToCannedResponseCategories < ActiveRecord::Migration[7.0]
  def change
    # visibility: 0 = everyone (all agents), 1 = only_me, 2 = specific_team.
    # Existing categories default to `everyone` so nothing is hidden post-migration.
    add_column :canned_response_categories, :visibility, :integer, null: false, default: 0
    add_column :canned_response_categories, :user_id, :bigint
    add_column :canned_response_categories, :team_id, :bigint

    add_index :canned_response_categories, :user_id
    add_index :canned_response_categories, :team_id
  end
end
