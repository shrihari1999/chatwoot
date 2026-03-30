class CreateChannelLazada < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_lazada do |t|
      t.integer :account_id, null: false
      t.string :shop_id, null: false
      t.string :app_key, null: false
      t.string :app_secret, null: false
      t.string :access_token, null: false
      t.timestamps
    end

    add_index :channel_lazada, :shop_id, unique: true
  end
end
