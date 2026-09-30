class ChangeTeamsAllowAutoAssignDefaultToFalse < ActiveRecord::Migration[7.1]
  def change
    change_column_default :teams, :allow_auto_assign, from: true, to: false
  end
end
