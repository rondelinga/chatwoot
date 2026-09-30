class ChatQueue::DirectAssignmentService
  pattr_initialize [:account!, :conversation!, :agent!]

  def assign!
    cid = conversation.id
    Rails.logger.info("[QUEUE][direct_assign][conv=#{cid}] Start assign to agent #{agent.id}")

    Conversation.transaction do
      return nil unless limit_guard.assignable?(agent.id)

      locked_conversation = Conversation.lock.find(conversation.id)
      return nil if locked_conversation.assignee_id.present?
      return nil unless allowed?(locked_conversation)

      locked_conversation.update!(
        assignee: agent,
        status: :open,
        updated_at: Time.current
      )
      notify_assigned(locked_conversation, cid)
      locked_conversation
    end
  rescue ActiveRecord::RecordNotSaved, ActiveRecord::RecordInvalid => e
    Rails.logger.error("[QUEUE][direct_assign][conv=#{conversation.id}] Exception: #{e.class} #{e.message}")
    nil
  end

  private

  def limit_guard
    @limit_guard ||= ChatQueue::Agents::LimitGuardService.new(account: account)
  end

  def allowed?(locked_conversation)
    ChatQueue::Agents::PermissionsService.new(account: account).allowed?(locked_conversation, agent)
  end

  def notify_assigned(locked_conversation, cid)
    Rails.logger.info("[QUEUE][direct_assign][conv=#{cid}] Sending assigned notification")
    ChatQueue::Queue::NotificationService.new(conversation: locked_conversation).send_assigned_notification
  end
end
