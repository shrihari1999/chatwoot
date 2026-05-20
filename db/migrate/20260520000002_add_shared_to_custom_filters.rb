class AddSharedToCustomFilters < ActiveRecord::Migration[7.0]
  # Renumbered from 20260515000000 during the v4.14.0 upstream sync — that
  # timestamp collided with upstream's EnqueueValidateOpenaiHooksJob. Guarded
  # so re-running on DBs where the original migration already applied is a
  # no-op.
  def up
    return if column_exists?(:custom_filters, :shared)

    add_column :custom_filters, :shared, :boolean, default: false, null: false
    CustomFilter.unscoped.in_batches.update_all(shared: true) # rubocop:disable Rails/SkipsModelValidations
  end

  def down
    remove_column :custom_filters, :shared if column_exists?(:custom_filters, :shared)
  end
end
