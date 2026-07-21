# Inbound Lazada and TikTok Shop webhooks locate the conversation by the platform's own
# id, which lives in conversations.additional_attributes. Without an index that lookup is
# an inbox_id index scan followed by a filter over every conversation in the inbox — fine
# at a few hundred rows, but the TikTok Shop inbox is growing steadily.
#
# The predicate is `IS NOT NULL` rather than the `?` key-existence operator on purpose:
# the planner can prove that `expr = 'value'` implies `expr IS NOT NULL` (strict operator),
# so the partial index is actually usable by the webhook query. It cannot prove key
# existence, which would leave the index built but ignored.
class AddConversationPlatformIdIndexes < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  INDEXES = {
    'index_conversations_on_lazada_session_id' => 'lazada_session_id',
    'index_conversations_on_tiktok_shop_conversation_id' => 'tiktok_shop_conversation_id'
  }.freeze

  def up
    INDEXES.each do |name, key|
      execute <<~SQL.squish
        CREATE INDEX CONCURRENTLY IF NOT EXISTS #{name}
          ON conversations ((additional_attributes ->> '#{key}'))
          WHERE (additional_attributes ->> '#{key}') IS NOT NULL
      SQL
    end
  end

  def down
    INDEXES.each_key do |name|
      execute "DROP INDEX CONCURRENTLY IF EXISTS #{name}"
    end
  end
end
