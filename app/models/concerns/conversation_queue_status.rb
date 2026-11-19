# Keeps a queued conversation consistent with its assignee and queue record.
# The queued status stays on Conversation; these callbacks only apply it.
module ConversationQueueStatus
  extend ActiveSupport::Concern

  private

  def leave_queue_if_assignee_present
    return unless account.queue_enabled?
    return unless saved_change_to_assignee_id? || saved_change_to_assignee_agent_bot_id?
    return if assignee_id.blank? && assignee_agent_bot_id.blank?

    ChatQueue::QueueService.new(account: account).remove_from_queue(self, reason: :other)
  end

  def process_queue_on_assignment_change
    return unless account.queue_enabled?
    return unless queue_assignment_change?

    open! if assignee_present? && queued?
    ChatQueue::ProcessQueueJob.perform_later(account.id) if should_process_queue_after_assignment_change?
  end

  def queue_assignment_change?
    saved_change_to_assignee_id? || saved_change_to_assignee_agent_bot_id? || saved_change_to_status?
  end

  def should_process_queue_after_assignment_change?
    resolved? || assignee_id.blank? || saved_change_to_assignee_id?
  end

  def enforce_queue_status_invariants
    return unless account&.queue_enabled?
    return unless assignee_present?

    self.status = :open if queued?
  end

  def assignee_present?
    assignee_id.present? || assignee_agent_bot_id.present?
  end

  def remove_from_queue_if_status_changed
    return unless saved_change_to_status?
    return unless account.queue_enabled?

    old_status, new_status = saved_change_to_status

    reason = if new_status == 'resolved'
               :resolved
             elsif old_status == 'queued' && new_status != 'queued'
               :other
             else
               return
             end

    ChatQueue::QueueService.new(account: account).remove_from_queue(self, reason: reason)
  end
end
