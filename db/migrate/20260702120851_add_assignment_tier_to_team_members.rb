class AddAssignmentTierToTeamMembers < ActiveRecord::Migration[7.1]
  def change
    add_column :team_members, :assignment_tier, :integer, default: 0, null: false
  end
end
