class ChatQueue::Agents::TierAssignmentService
  pattr_initialize [:account!, :conversation!]

  def assign_primary_then_backup
    return true if assign_for_tier(:primary)

    assign_for_tier(:backup)
  end

  def assign_for_tier(tier)
    each_tier_agent(tier) do |agent|
      assigned = ChatQueue::DirectAssignmentService.new(
        account: account,
        conversation: conversation,
        agent: agent
      ).assign!
      return true if assigned
    end

    false
  end

  private

  def each_tier_agent(tier)
    conversation.reload

    agent_ids = ChatQueue::Agents::OnlineAgentsService.new(
      account: account,
      team_id: conversation.team_id,
      assignment_tier: tier
    ).list

    agents = User.where(id: agent_ids).index_by(&:id)
    permissions = ChatQueue::Agents::PermissionsService.new(account: account)

    agent_ids.each do |agent_id|
      agent = agents[agent_id]
      next unless agent
      next unless permissions.allowed?(conversation, agent)

      yield agent
    end
  end
end
