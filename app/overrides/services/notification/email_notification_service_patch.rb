module Overrides
  module Notification::EmailNotificationServicePatch
    def perform
      return
    end
  end
end

Notification::EmailNotificationService.prepend(Overrides::Notification::EmailNotificationServicePatch)
