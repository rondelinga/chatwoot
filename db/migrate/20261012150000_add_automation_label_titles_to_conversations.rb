class AddAutomationLabelTitlesToConversations < ActiveRecord::Migration[7.1]
  def change
    add_column :conversations, :automation_label_titles, :string, array: true, default: [], null: false
  end
end
