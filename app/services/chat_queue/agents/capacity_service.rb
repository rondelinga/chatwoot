class ChatQueue::Agents::CapacityService
  ACTIVE_STATUSES = %i[open].freeze

  pattr_initialize [:account!]

  def available_slots
    total = total_online_limits
    return nil if total.nil?

    [total - active_chats_count, 0].max
  end

  def active_chats_count
    active_conversations.where(assignee_id: online_agent_ids).count
  end

  def total_online_limits
    return 0 if online_agent_ids.empty?

    limits = online_agent_ids.map { |id| limits_service.limit_for(id) }
    return nil if limits.any?(&:nil?)

    limits.sum
  end

  def active_conversations_for(agent_id)
    active_conversations.where(assignee_id: agent_id)
  end

  private

  def active_conversations
    Conversation.where(account_id: account.id, status: ACTIVE_STATUSES)
  end

  def online_agent_ids
    @online_agent_ids ||= (OnlineStatusTracker.get_available_users(account.id) || {})
                          .select { |_id, status| status == 'online' }
                          .keys
                          .map(&:to_i)
  end

  def limits_service
    @limits_service ||= ChatQueue::Agents::LimitsService.new(account: account)
  end
end
