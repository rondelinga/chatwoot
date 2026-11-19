class CreateInboxTeams < ActiveRecord::Migration[7.1]
  def change
    create_table :inbox_teams do |t|
      t.references :inbox, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.timestamps
    end

    add_index :inbox_teams, [:inbox_id, :team_id], unique: true
  end
end
