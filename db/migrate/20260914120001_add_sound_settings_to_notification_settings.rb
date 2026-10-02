class AddSoundSettingsToNotificationSettings < ActiveRecord::Migration[7.2]
  def change
    change_table :notification_settings, bulk: true do |t|
      t.boolean :new_conversation_sound_enabled, default: true, null: false
      t.string :new_conversation_sound, default: 'bell', null: false
      t.integer :new_conversation_volume, default: 80, null: false
      t.bigint :new_conversation_custom_sound_id

      t.boolean :new_message_sound_enabled, default: true, null: false
      t.string :new_message_sound, default: 'pop', null: false
      t.integer :new_message_volume, default: 60, null: false
      t.bigint :new_message_custom_sound_id
    end

    add_index :notification_settings, :new_conversation_custom_sound_id
    add_index :notification_settings, :new_message_custom_sound_id
    add_foreign_key :notification_settings, :notification_sounds,
                    column: :new_conversation_custom_sound_id, on_delete: :nullify
    add_foreign_key :notification_settings, :notification_sounds,
                    column: :new_message_custom_sound_id, on_delete: :nullify
  end
end
