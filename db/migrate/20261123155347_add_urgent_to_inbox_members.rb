class AddUrgentToInboxMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :inbox_members, :urgent, :boolean, default: false, null: false
  end
end
