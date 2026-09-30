class ChatQueue::Queue::AssignmentService
  pattr_initialize [:account!, :entry!, :agent!]

  def assign!
    cid = entry.conversation_id
    Rails.logger.info("[QUEUE][assign_entry][conv=#{cid}] Start assign to agent #{agent.id}")

    ConversationQueue.transaction do
      locked_entry = ConversationQueue.lock.find(entry.id)
      locked_conversation = Conversation.lock.find(locked_entry.conversation_id)

      next locked_conversation if skip_due_to_already_assigned?(locked_entry, locked_conversation, cid)
      next unless validate_agent_limit!(agent, cid)

      perform_assignment_steps(locked_entry, locked_conversation, cid)
      locked_conversation
    end
  rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid => e
    Rails.logger.error("[QUEUE][assign_entry][conv=#{entry.conversation_id}] Exception: #{e.class} #{e.message}")
    nil
  end

  private

  attr_reader :account, :entry, :agent

  def skip_due_to_already_assigned?(locked_entry, conversation, cid)
    already_assigned?(locked_entry, conversation, cid)
  end

  def perform_assignment_steps(locked_entry, conversation, cid)
    update_queue_entry!(locked_entry, cid)
    update_conversation!(conversation, agent, cid)
    update_statistics(locked_entry)
    notify_assigned(conversation, cid)
  end

  def already_assigned?(locked_entry, conversation, cid)
    if locked_entry.status == 'assigned'
      Rails.logger.info("[QUEUE][assign_entry][conv=#{cid}] Skip: already assigned")
      return true
    end

    if conversation.assignee_id.present?
      Rails.logger.info("[QUEUE][assign_entry][conv=#{cid}] Skip: conversation already has assignee #{conversation.assignee_id}")
      return true
    end

    false
  end

  def validate_agent_limit!(agent, cid)
    return true if limit_guard.assignable?(agent.id)

    Rails.logger.info("[QUEUE][assign_entry][conv=#{cid}] Abort: agent #{agent.id} exceeds limit")
    raise ActiveRecord::Rollback
  end

  def limit_guard
    @limit_guard ||= ChatQueue::Agents::LimitGuardService.new(account: account)
  end

  def update_queue_entry!(locked_entry, cid)
    Rails.logger.info("[QUEUE][assign_entry][conv=#{cid}] Updating queue entry to assigned")
    locked_entry.update!(
      status: :assigned,
      assigned_at: Time.current
    )
  end

  def update_conversation!(conversation, agent, cid)
    Rails.logger.info("[QUEUE][assign_entry][conv=#{cid}] Updating conversation assignee")
    conversation.update!(
      assignee: agent,
      status: :open,
      updated_at: Time.current
    )
  end

  def update_statistics(locked_entry)
    cid = locked_entry.conversation_id
    Rails.logger.info("[QUEUE][stats][conv=#{cid}] Updating stats")

    wait_time = locked_entry.wait_time_seconds

    QueueStatistic.update_statistics_for(
      account.id,
      wait_time_seconds: wait_time,
      assigned: true
    )
  end

  def notify_assigned(conversation, cid)
    Rails.logger.info("[QUEUE][assign_entry][conv=#{cid}] Sending assigned notification")
    ChatQueue::Queue::NotificationService.new(conversation: conversation).send_assigned_notification
  end
end
