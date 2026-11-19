# Triggered when an agent transitions to 'busy' status.
# Schedules itself to run after the account's configured timeout (in minutes).
# If the agent is still busy when the job runs, resets them to 'offline'.
#
# Date modified: 12.05.2026
class BusyToOfflineResetJob < ApplicationJob
  queue_as :scheduled_jobs

  def perform(account_id, user_id, busy_since)
    account_user = resettable_account_user(account_id, user_id, busy_since)
    return unless account_user

    account_user.update!(availability: :offline)
    OnlineStatusTracker.set_status(account_id, user_id, 'offline')
    Rails.logger.info("[BusyToOfflineResetJob] Reset user #{user_id} to offline in account #{account_id}")
  end

  private

  def resettable_account_user(account_id, user_id, busy_since)
    account = Account.find_by(id: account_id)
    return unless account && timeout_enabled?(account)

    account_user = account.account_users.find_by(user_id: user_id)
    return unless account_user&.busy?
    return if account_user.updated_at.to_i > busy_since

    account_user
  end

  def timeout_enabled?(account)
    timeout_minutes = account.busy_to_offline_timeout&.to_i
    timeout_minutes.present? && timeout_minutes.positive?
  end
end
