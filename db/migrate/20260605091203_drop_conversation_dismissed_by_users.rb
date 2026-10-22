class DropConversationDismissedByUsers < ActiveRecord::Migration[7.1]
  def change
    drop_table :conversation_dismissed_by_users # rubocop:todo Rails/ReversibleMigration
  end
end
