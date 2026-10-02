module AutoAssignmentHandlerQueue
  private

  def handle_queue_assignment
    return if team_id.blank? && team_routed_inbox?

    reconcile_invalid_queue_state
    queue_service = ChatQueue::QueueService.new(account: account)
    return if queued_or_assigned?

    clear_assignee_if_present
    assign_or_enqueue(queue_service)
  end

  def assign_or_enqueue(queue_service)
    if queue_empty_for?(self)
      handle_direct_or_queued_assignment(queue_service)
    else
      queue_service.add_to_queue(self)
    end
  end

  def reconcile_invalid_queue_state
    return unless account.queue_enabled?
    return unless queued? && (assignee_id.present? || assignee_agent_bot_id.present?)

    update!(status: :open)
  end

  def queued_or_assigned?
    queued? || assignee_id.present? || assignee_agent_bot_id.present?
  end

  def clear_assignee_if_present
    updates = {}
    updates[:assignee_id] = nil if assignee_id.present?
    updates[:assignee_agent_bot_id] = nil if assignee_agent_bot_id.present?
    update_columns(updates) if updates.any? # rubocop:disable Rails/SkipsModelValidations
  end

  def queue_empty_for?(conversation)
    ChatQueue::Queue::FetchService.new(account: account)

    scope = ConversationQueue.for_account(account.id).waiting.joins(:conversation)
    if conversation.team_id.present?
      scope.where(conversations: { team_id: conversation.team_id }).none?
    else
      scope.where(conversations: { inbox_id: conversation.inbox_id }).none?
    end
  end

  def handle_direct_or_queued_assignment(queue_service)
    return queue_service.add_to_queue(self) unless assignee_id.nil?

    return if ChatQueue::Agents::TierAssignmentService.new(account: account, conversation: self).assign_primary_then_backup

    queue_service.add_to_queue(self)
  end
end
