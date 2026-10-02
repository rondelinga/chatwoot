module AutoAssignment::AgentAssignmentCapacity
  private

  def active_chat_counts_for(agent_ids)
    Conversation
      .where(assignee_id: agent_ids, account_id: conversation.account_id)
      .where.not(status: :resolved)
      .group(:assignee_id)
      .count
      .tap { |h| agent_ids.each { |id| h[id] ||= 0 } }
  end

  def filter_agents_below_limit(agent_ids, counts)
    agent_ids.reject { |id| agent_at_or_over_limit?(id, counts) }
  end

  def agent_at_or_over_limit?(agent_id, counts)
    limit = effective_limit_for_agent(agent_id)
    return false if limit.nil?

    (counts[agent_id] || 0) >= limit
  end

  def effective_limit_for_agent(agent_id)
    account = conversation.account
    account_user = AccountUser.find_by(account_id: account.id, user_id: agent_id)

    return account_user.active_chat_limit.to_i if account_user&.active_chat_limit_enabled? && account_user.active_chat_limit.present?

    return account.active_chat_limit.to_i if account.active_chat_limit_enabled? && account.active_chat_limit.present?

    nil
  end

  def last_closed_chat_times_for(agent_ids)
    Conversation
      .where(assignee_id: agent_ids, status: :resolved)
      .group(:assignee_id)
      .pluck(:assignee_id, Arel.sql('MAX(updated_at)'))
      .to_h
  end

  def pick_least_recent_assigned(agent_ids, counts, last_closed_times)
    stats = agent_ids.map do |id|
      { id: id, active: counts[id] || 0, last_closed: last_closed_times[id] || Time.zone.at(0) }
    end

    stats.min_by { |s| [s[:active], s[:last_closed]] }[:id]
  end
end
