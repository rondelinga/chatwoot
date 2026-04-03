module Notification::EmailNotificationServicePatch
  def perform
    return
  end
end

Notification::EmailNotificationService.prepend(Notification::EmailNotificationServicePatch)
