class ChatQueue::Agents::LimitGuardService
  pattr_initialize [:account!]

  def assignable?(agent_id)
    return false unless lock_account_user!(agent_id)

    limit = limit_for(agent_id)
    return true if limit.nil?

    active_count_locked(agent_id) < limit
  end

  private

  def lock_account_user!(agent_id)
    AccountUser.where(account_id: account.id, user_id: agent_id).lock.first
  end

  def limit_for(agent_id)
    ChatQueue::Agents::LimitsService.new(account: account).limit_for(agent_id)
  end

  def active_count_locked(agent_id)
    capacity_service
      .active_conversations_for(agent_id)
      .lock('FOR UPDATE')
      .pluck(:id)
      .size
  end

  def capacity_service
    @capacity_service ||= ChatQueue::Agents::CapacityService.new(account: account)
  end
end
