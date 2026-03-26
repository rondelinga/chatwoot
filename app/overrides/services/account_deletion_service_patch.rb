module Overrides
  module AccountDeletionServicePatch
    def perform
      Rails.logger.info("Deleting account #{account.id} - #{account.name} that was marked for deletion")

      soft_delete_orphaned_users
      # send_compliance_notification
      DeleteObjectJob.perform_later(account)
    end
  end
end

AccountDeletionService.prepend(Overrides::AccountDeletionServicePatch)
