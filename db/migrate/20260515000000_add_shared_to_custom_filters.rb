class AddSharedToCustomFilters < ActiveRecord::Migration[7.0]
  def up
    add_column :custom_filters, :shared, :boolean, default: false, null: false
    CustomFilter.unscoped.in_batches.update_all(shared: true)
  end

  def down
    remove_column :custom_filters, :shared
  end
end
