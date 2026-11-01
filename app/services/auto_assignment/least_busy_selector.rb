class AutoAssignment::LeastBusySelector
  pattr_initialize [:inbox!]

  # Fewest open chats in the account (the same count the chat limits use), then the agent
  # who closed a chat least recently.
  # Agents at their active chat limit are skipped.
  def select_agent(available_agents)
    ids = agent_users(available_agents).map(&:id)
    available_ids = ids - AgentActiveChatLimits.over_limit_ids(inbox.account, ids)
    return if available_ids.blank?

    User.find_by(id: least_busy_id(available_ids))
  end

  private

  def agent_users(available_agents)
    Array(available_agents).filter_map do |agent|
      next agent if agent.is_a?(User)

      agent.try(:user)
    end
  end

  def least_busy_id(agent_ids)
    counts = AgentActiveChatLimits.open_counts(inbox.account, agent_ids)
    min_count = agent_ids.map { |id| counts.fetch(id, 0) }.min
    least_busy = agent_ids.select { |id| counts.fetch(id, 0) == min_count }
    return least_busy.first if least_busy.one?

    last_closed = last_closed_chat_times_for(least_busy)
    least_busy.min_by { |id| last_closed[id] || Time.zone.at(0) }
  end

  def last_closed_chat_times_for(agent_ids)
    Conversation
      .where(assignee_id: agent_ids, account_id: inbox.account_id, status: :resolved)
      .group(:assignee_id)
      .pluck(:assignee_id, Arel.sql('MAX(COALESCE(resolved_at, updated_at))'))
      .to_h
  end
end
