class AddFreshchatImportIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    add_index :contacts,
              "((additional_attributes->>'freshchat_customer_id'))",
              name: 'index_contacts_on_freshchat_customer_id',
              where: "additional_attributes ? 'freshchat_customer_id'",
              algorithm: :concurrently

    add_index :conversations,
              "((additional_attributes->>'freshchat_conversation_id'))",
              name: 'index_conversations_on_freshchat_conversation_id',
              where: "additional_attributes ? 'freshchat_conversation_id'",
              algorithm: :concurrently

    add_index :messages,
              "((additional_attributes->>'freshchat_message_id'))",
              name: 'index_messages_on_freshchat_message_id',
              where: "additional_attributes ? 'freshchat_message_id'",
              algorithm: :concurrently
  end

  def down
    remove_index :messages, name: 'index_messages_on_freshchat_message_id', algorithm: :concurrently
    remove_index :conversations, name: 'index_conversations_on_freshchat_conversation_id', algorithm: :concurrently
    remove_index :contacts, name: 'index_contacts_on_freshchat_customer_id', algorithm: :concurrently
  end
end
