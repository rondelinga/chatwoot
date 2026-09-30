class AddIsDefaultToInboxTeams < ActiveRecord::Migration[7.1]
  def change
    add_column :inbox_teams, :is_default, :boolean, default: false, null: false
  end
end
