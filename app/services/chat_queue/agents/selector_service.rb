class ChatQueue::Agents::SelectorService
  pattr_initialize [:account!]

  # Picks one agent with the inbox assignment policy. Queue limits still apply.
  def pick_best_agent_for(conversation)
    members = eligible_members(conversation)
    return if members.blank?

    AutoAssignment::AgentSelector.new(inbox: conversation.inbox, conversation: conversation).select(members)
  end

  private

  def eligible_members(conversation)
    inbox = conversation.inbox
    return [] if inbox.blank?

    user_ids = candidate_user_ids(conversation, inbox)
    return [] if user_ids.blank?

    inbox.inbox_members.where(user_id: user_ids).includes(:user).select do |member|
      permissions.allowed?(conversation, member.user) && availability.available?(member.user)
    end
  end

  # Online agents of the conversation's team who still have capacity under the inbox
  # assignment limit or agent capacity policy (personal and account limits included).
  def candidate_user_ids(conversation, inbox)
    return [] if conversation.team_id.present? && !conversation.team&.allow_auto_assign?

    user_ids = online_user_ids & inbox.member_ids_with_assignment_capacity
    user_ids &= conversation.team.members.ids if conversation.team_id.present?
    user_ids
  end

  def availability
    @availability ||= ChatQueue::Agents::AvailabilityService.new(account: account)
  end

  def permissions
    @permissions ||= ChatQueue::Agents::PermissionsService.new(account: account)
  end

  def online_user_ids
    (OnlineStatusTracker.get_available_users(account.id) || {})
      .select { |_id, status| status == 'online' }
      .keys
      .map(&:to_i)
  end
end
