class CreateCannedResponseScopes < ActiveRecord::Migration[7.1]
  def change
    create_table :canned_response_scopes do |t|
      t.references :canned_response, null: false, foreign_key: true
      t.integer :user_id, null: true
      t.bigint :team_id, null: true
      t.integer :inbox_id, null: true

      t.timestamps
    end

    add_index :canned_response_scopes, :user_id
    add_index :canned_response_scopes, :team_id
    add_index :canned_response_scopes, :inbox_id
  end
end
