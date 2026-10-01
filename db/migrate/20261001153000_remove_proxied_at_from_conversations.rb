class RemoveProxiedAtFromConversations < ActiveRecord::Migration[7.1]
  def up
    remove_index :conversations, :proxied_at, if_exists: true
    remove_column :conversations, :proxied_at, if_exists: true
  end

  def down
    add_column :conversations, :proxied_at, :datetime
    add_index :conversations, :proxied_at
  end
end
