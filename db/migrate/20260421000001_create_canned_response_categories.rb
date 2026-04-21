class CreateCannedResponseCategories < ActiveRecord::Migration[7.0]
  def change
    create_table :canned_response_categories do |t|
      t.integer :account_id, null: false
      t.string :name, null: false
      t.timestamps
    end

    add_index :canned_response_categories, :account_id
    add_index :canned_response_categories, [:account_id, :name], unique: true

    add_column :canned_responses, :category_id, :integer
    add_index :canned_responses, :category_id
  end
end
