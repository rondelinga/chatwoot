class ChatQueue::Agents::LimitsService
  pattr_initialize [:account!]

  def limit_for(agent_id)
    limit = AgentActiveChatLimits.limit_for(account, agent_id)
    Rails.logger.info("[QUEUE][limit][agent=#{agent_id}] limit=#{limit || 'none'}")
    limit
  end
end
