class AddSoftDeleteFieldsToMessages < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_column :messages, :deleted_at, :datetime
    add_column :messages, :deleted_by_id, :integer
    add_column :messages, :original_content, :text
    add_column :messages, :audit_private_note_id, :integer

    add_index :messages, :deleted_at, algorithm: :concurrently, if_not_exists: true

    add_foreign_key :messages, :users, column: :deleted_by_id
    add_foreign_key :messages, :messages, column: :audit_private_note_id
  end
end
