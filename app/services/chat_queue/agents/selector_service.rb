class ChatQueue::Agents::SelectorService
  pattr_initialize [:account!]

  def pick_best_agent_for(conversation)
    primary_agent = pick_from_tier(conversation, :primary)
    return primary_agent if primary_agent

    pick_from_tier(conversation, :backup)
  end

  def online_agents
    online_agent_ids(team_id: nil).filter_map { |id| User.find_by(id: id) }
  end

  private

  def pick_from_tier(conversation, tier)
    cid = conversation.id
    Rails.logger.info("[QUEUE][pick][conv=#{cid}] Selecting #{tier} agent, team=#{conversation.team_id.inspect}")

    online_agents_for(conversation, tier: tier).each do |agent|
      allowed = allowed_for_conversation?(conversation, agent)
      available = available?(agent)

      Rails.logger.info("[QUEUE][pick][conv=#{cid}] Agent #{agent.id} (#{tier}): allowed=#{allowed}, available=#{available}")

      next unless allowed && available

      Rails.logger.info("[QUEUE][pick][conv=#{cid}] Selected #{tier} agent #{agent.id}")
      return agent
    end

    Rails.logger.info("[QUEUE][pick][conv=#{cid}] No #{tier} agent found")
    nil
  end

  def online_agents_for(conversation, tier: nil)
    online_agent_ids(team_id: conversation.team_id, tier: tier).filter_map { |id| User.find_by(id: id) }
  end

  def online_agent_ids(team_id:, tier: nil)
    ChatQueue::Agents::OnlineAgentsService.new(
      account: account,
      team_id: team_id,
      assignment_tier: tier
    ).list
  end

  def allowed_for_conversation?(conversation, agent)
    ChatQueue::Agents::PermissionsService.new(account: account).allowed?(conversation, agent)
  end

  def available?(agent)
    ChatQueue::Agents::AvailabilityService.new(account: account).available?(agent)
  end
end
