class AddAccountAssigneeStatusUpdatedAtIndexToConversations < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :conversations, [:account_id, :assignee_id, :status, :updated_at],
              name: 'index_conversations_on_account_assignee_status_updated_at',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
