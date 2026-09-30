class ChatQueue::Agents::PermissionsService
  pattr_initialize [:account!]

  def allowed?(conversation, agent)
    return false if agent.nil? || conversation.nil?

    cid = conversation.id

    allowed = InboxMember.exists?(inbox_id: conversation.inbox_id, user_id: agent.id)
    Rails.logger.info("[QUEUE][allowed][conv=#{cid}] Agent #{agent.id} inbox_allowed=#{allowed}")
    return false unless allowed

    if conversation.team_id.present?
      in_team = TeamMember.exists?(team_id: conversation.team_id, user_id: agent.id)
      Rails.logger.info("[QUEUE][allowed][conv=#{cid}] Agent #{agent.id} in_team=#{in_team} (team=#{conversation.team_id})")
      return false unless in_team
    end

    true
  end
end
