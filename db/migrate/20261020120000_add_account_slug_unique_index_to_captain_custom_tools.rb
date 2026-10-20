class AddAccountSlugUniqueIndexToCaptainCustomTools < ActiveRecord::Migration[7.1]
  def change
    add_index :captain_custom_tools, [:account_id, :slug],
              unique: true,
              name: 'index_captain_custom_tools_on_account_id_and_slug',
              if_not_exists: true
  end
end
