# Reconciles the fork's feature-flag storage with upstream v4.16.0's layout.
#
# The fork (PR #107) fixed the 63-flag overflow with a `feature_flags_extended`
# bigint column, partitioning by 1-based feature index. Upstream v4.16.0 solved
# the same overflow differently: a per-feature `column:` key in features.yml with
# columns `feature_flags` + `feature_flags_ext_1`. This sync adopts upstream's
# scheme, so production's physically-stored bits must be remapped once.
#
# Cause of the drift: the fork inserted `channel_tiktok_shop` at feature_flags
# bit 60, which pushed the next three flags down one bit and overflowed
# `advanced_assignment` into feature_flags_extended:1. Upstream never had
# channel_tiktok_shop, so its bits 60-63 are csat/captain/conv_req/adv_assign.
#
#   OLD (fork)                             NEW (upstream v4.16.0)
#   feature_flags b60 channel_tiktok_shop    -> feature_flags_ext_1 b6
#   feature_flags b61 csat_review_notes      -> feature_flags     b60
#   feature_flags b62 captain_tasks          -> feature_flags     b61
#   feature_flags b63 conv_required_attrs    -> feature_flags     b62
#   feature_flags_extended b1 adv_assignment -> feature_flags     b63
#
# Bits 1..59 are identical on both sides and are left untouched. The remap is a
# bijection, so `down` restores the fork layout exactly.
class MigrateFeatureFlagsToUpstreamColumns < ActiveRecord::Migration[7.1]
  # Bare AR class: avoids FlagShihTzu (already reconfigured for the new columns)
  # so we read/write the raw bigint column values directly.
  class MigrationAccount < ActiveRecord::Base # rubocop:disable Style/OneClassPerFile
    self.table_name = 'accounts'
  end

  BITS_1_TO_59 = (1 << 59) - 1
  TIKTOK_EXT1_BIT = 1 << 5 # feature_flags_ext_1 bit 6

  def up
    # Idempotency guard: only run while the fork's column still exists.
    return unless column_exists?(:accounts, :feature_flags_extended)

    MigrationAccount.reset_column_information
    MigrationAccount.find_each do |account|
      new_ff, new_e1 = forward(account.feature_flags.to_i, account.feature_flags_extended.to_i, account.feature_flags_ext_1.to_i)
      account.update_columns(feature_flags: new_ff, feature_flags_ext_1: new_e1) # rubocop:disable Rails/SkipsModelValidations
    end

    remove_column :accounts, :feature_flags_extended
  end

  def down
    add_column :accounts, :feature_flags_extended, :bigint, default: 0, null: false unless column_exists?(:accounts, :feature_flags_extended)

    MigrationAccount.reset_column_information
    MigrationAccount.find_each do |account|
      old_ff, old_ext, old_e1 = backward(account.feature_flags.to_i, account.feature_flags_ext_1.to_i)
      account.update_columns(feature_flags: old_ff, feature_flags_extended: old_ext, feature_flags_ext_1: old_e1) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  private

  # OLD fork layout -> upstream layout. Returns [feature_flags, feature_flags_ext_1].
  def forward(old_ff, old_ext, old_e1)
    tiktok  = (old_ff >> 59) & 1 # old bit 60
    csat    = (old_ff >> 60) & 1 # old bit 61
    captain = (old_ff >> 61) & 1 # old bit 62
    convreq = (old_ff >> 62) & 1 # old bit 63
    adv     = old_ext & 1        # extended bit 1

    new_ff = (old_ff & BITS_1_TO_59) | (csat << 59) | (captain << 60) | (convreq << 61) | (adv << 62)
    new_e1 = (old_e1 & ~TIKTOK_EXT1_BIT) | (tiktok << 5)
    [new_ff, new_e1]
  end

  # upstream layout -> OLD fork layout. Returns [feature_flags, feature_flags_extended, feature_flags_ext_1].
  def backward(new_ff, new_e1)
    tiktok  = (new_e1 >> 5) & 1  # ext_1 bit 6
    csat    = (new_ff >> 59) & 1 # new bit 60
    captain = (new_ff >> 60) & 1 # new bit 61
    convreq = (new_ff >> 61) & 1 # new bit 62
    adv     = (new_ff >> 62) & 1 # new bit 63

    old_ff = (new_ff & BITS_1_TO_59) | (tiktok << 59) | (csat << 60) | (captain << 61) | (convreq << 62)
    [old_ff, adv, new_e1 & ~TIKTOK_EXT1_BIT]
  end
end
