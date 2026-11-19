class AddNotificationTogglesToInboxes < ActiveRecord::Migration[7.2]
  def change
    add_column :inboxes, :queue_notification_enabled, :boolean, default: true, null: false
    add_column :inboxes, :resolution_notification_enabled, :boolean, default: true, null: false
  end
end
