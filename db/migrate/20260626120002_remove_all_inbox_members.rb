class RemoveAllInboxMembers < ActiveRecord::Migration[7.1]
  def up
    count = InboxMember.delete_all
    say "Removed #{count} inbox_member record(s)"
  end
 
  def down
    raise ActiveRecord::IrreversibleMigration, 'Cannot restore deleted inbox_members'
  end
end
