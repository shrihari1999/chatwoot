class AddFeatureFlagsExtendedToAccounts < ActiveRecord::Migration[7.1]
  # Second bigint bitmask column for feature flags. The original `feature_flags`
  # column is a SIGNED bigint, so it can hold at most 63 flags (bits 1..63; the
  # 64th flag would need bit 2^63 which overflows). Features beyond index 63
  # spill into this column. See Featurable for the index->column partition.
  #
  # Purely additive: existing rows default to 0 (no flag at index >= 64 is set on
  # the existing account), so no data backfill or bit remap is required.
  def change
    add_column :accounts, :feature_flags_extended, :bigint, default: 0, null: false
  end
end
