class BackfillCannedResponseCategory < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    Account.find_each do |account|
      next unless CannedResponse.where(account: account).exists?

      category = CannedResponseCategory.find_or_create_by!(account: account, name: 'General')
      CannedResponse.where(account: account, category_id: nil).update_all(category_id: category.id)
    end
  end

  def down
    CannedResponseCategory.where(name: 'General').each do |cat|
      CannedResponse.where(category_id: cat.id).update_all(category_id: nil)
      cat.destroy
    end
  end
end
