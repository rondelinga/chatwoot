class AddRoutingToInboxTeams < ActiveRecord::Migration[7.1]
  def change
    add_reference :inbox_teams, :routing_type, foreign_key: true, null: true
    add_reference :inbox_teams, :agent_bot, foreign_key: true, null: true
  end
end
