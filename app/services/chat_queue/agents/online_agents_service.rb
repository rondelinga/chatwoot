class ChatQueue::Agents::OnlineAgentsService
  pattr_initialize [:account!, :team_id, :assignment_tier]

  def list
    Rails.logger.info(
      "[QUEUE][online] Fetching online agents for account #{account.id}, " \
      "team=#{team_id.inspect}, tier=#{assignment_tier.inspect}"
    )

    agent_ids = fetch_online_agent_ids
    agent_ids = filter_by_team(agent_ids) if team_id.present?
    agent_ids = filter_by_tier(agent_ids) if assignment_tier.present?

    Rails.logger.info("[QUEUE][online] Online IDs after filters: #{agent_ids.inspect}")

    stats = build_agent_stats(agent_ids)
    sorted = sort_agents(stats)

    Rails.logger.info("[QUEUE][online] Sorted agent list: #{sorted.inspect}")
    sorted
  end

  private

  def fetch_online_agent_ids
    (OnlineStatusTracker.get_available_users(account.id) || {})
      .select { |_id, status| status == 'online' }
      .keys
      .map(&:to_i)
  end

  def filter_by_team(agent_ids)
    team_member_ids = TeamMember.where(team_id: team_id).pluck(:user_id)
    filtered = agent_ids & team_member_ids
    Rails.logger.info("[QUEUE][online] Team #{team_id} members online: #{filtered.inspect}")
    filtered
  end

  def filter_by_tier(agent_ids)
    return [] if team_id.blank?

    TeamMember
      .where(team_id: team_id, user_id: agent_ids, assignment_tier: assignment_tier)
      .pluck(:user_id)
  end

  def build_agent_stats(agent_ids)
    agent_ids.map { |id| agent_stat_record(id) }
  end

  def agent_stat_record(id)
    active_count = capacity_service.active_conversations_for(id).count

    last_closed = Conversation
                  .where(account_id: account.id, assignee_id: id, status: :resolved)
                  .order(updated_at: :desc)
                  .pick(:updated_at) || Time.zone.at(0)

    Rails.logger.info("[QUEUE][online] Agent #{id}: active=#{active_count}, last_closed=#{last_closed}")

    {
      id: id,
      active: active_count,
      last_closed: last_closed
    }
  end

  def sort_agents(stats)
    stats.sort_by { |a| [a[:active], a[:last_closed]] }.pluck(:id)
  end

  def capacity_service
    @capacity_service ||= ChatQueue::Agents::CapacityService.new(account: account)
  end
end
