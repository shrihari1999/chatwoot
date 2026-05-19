class CreateChannelTiktokShop < ActiveRecord::Migration[7.0]
  def change
    create_table :channel_tiktok_shop do |t|
      t.integer :account_id, null: false
      t.string :shop_id, null: false
      t.string :shop_cipher, null: false
      t.string :seller_name
      t.string :region, default: 'others'
      t.text :access_token, null: false
      t.text :refresh_token, null: false
      t.datetime :access_token_expires_at
      t.datetime :refresh_token_expires_at
      t.integer :authorization_error_count, default: 0
      t.timestamps
    end

    add_index :channel_tiktok_shop, :shop_id, unique: true
    add_index :channel_tiktok_shop, :shop_cipher, unique: true
    add_index :channel_tiktok_shop, :account_id
  end
end
