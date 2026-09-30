class ChatQueue::Queue::EntryService
  pattr_initialize [:account!]

  def prepare_for_queue!(conversation)
    queued_conversation = nil

    Conversation.transaction do
      locked = Conversation.lock.find(conversation.id)
      prepare_conversation_for_queue!(locked)
      persist_queue_record!(locked)
      queued_conversation = locked
    end

    notify(queued_conversation)
  end

  private

  def prepare_conversation_for_queue!(conversation)
    cid = conversation.id
    changed = false

    if conversation.assignee_id.present?
      Rails.logger.info("[QUEUE][add][conv=#{cid}] Clearing assignee #{conversation.assignee_id}")
      conversation.assignee_id = nil
      changed = true
    end

    if conversation.assignee_agent_bot_id.present?
      Rails.logger.info("[QUEUE][add][conv=#{cid}] Clearing agent bot #{conversation.assignee_agent_bot_id}")
      conversation.assignee_agent_bot_id = nil
      changed = true
    end

    unless conversation.queued?
      Rails.logger.info("[QUEUE][add][conv=#{cid}] Updating conversation status to queued")
      conversation.status = :queued
      changed = true
    end

    conversation.save! if changed
  end

  def persist_queue_record!(conversation)
    cid = conversation.id
    Rails.logger.info("[QUEUE][add][conv=#{cid}] Creating or updating queue entry")

    queue_record = ConversationQueue.find_or_initialize_by(conversation: conversation)
    is_requeue = queue_record.persisted? && !queue_record.waiting?

    Rails.logger.info("[QUEUE][add][conv=#{cid}] Re-queueing existing record (was #{queue_record.status})") if is_requeue

    queue_record.assign_attributes(
      account: account,
      inbox_id: conversation.inbox_id,
      queued_at: Time.current,
      status: :waiting,
      assigned_at: nil,
      left_at: nil
    )

    queue_record.save!

    QueueStatistic.increment_queued(account.id) unless is_requeue
  end

  def notify(conversation)
    cid = conversation.id
    Rails.logger.info("[QUEUE][add][conv=#{cid}] Sending queue notification")

    ChatQueue::Queue::NotificationService.new(conversation: conversation).send_queue_notification
    ChatQueue::ProcessQueueJob.perform_later(account.id)
  end
end
