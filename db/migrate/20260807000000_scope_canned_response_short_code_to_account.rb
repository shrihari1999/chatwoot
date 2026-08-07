class ScopeCannedResponseShortCodeToAccount < ActiveRecord::Migration[7.1]
  def up
    # Drops the fork's per-category uniqueness in favour of upstream's account-wide rule.
    # Upstream carries no index here at all — uniqueness rests on the model validation —
    # so removing this leaves `canned_responses` matching upstream apart from `category_id`.
    #
    # Safe on live data: every short code in the account is already distinct, so nothing
    # collides under the stricter account-wide rule.
    remove_index :canned_responses, name: 'idx_canned_responses_unique_per_category'
  end

  def down
    # Fails if cross-category duplicates were created while the account-wide rule was in
    # force -- there is no way to re-establish the narrower index over data it never allowed.
    add_index :canned_responses,
              [:account_id, :category_id, :short_code],
              unique: true,
              name: 'idx_canned_responses_unique_per_category'
  end
end
