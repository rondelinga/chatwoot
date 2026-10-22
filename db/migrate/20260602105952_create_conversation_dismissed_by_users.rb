class CreateConversationDismissedByUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :conversation_dismissed_by_users do |t|
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    add_index :conversation_dismissed_by_users, [:conversation_id, :user_id], unique: true,
                                                                              name: 'idx_conv_dismissed_by_user'
  end
end
