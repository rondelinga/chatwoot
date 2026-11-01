class AddAssignmentTiersEnabledToTeams < ActiveRecord::Migration[7.1]
  def change
    add_column :teams, :assignment_tiers_enabled, :boolean, default: true, null: false
  end
end
