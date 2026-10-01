class CreateNotificationSounds < ActiveRecord::Migration[7.2]
  def change
    create_table :notification_sounds do |t|
      t.references :user, null: false, foreign_key: true
      t.string :filename, null: false
      t.timestamps
    end
  end
end
