class AutoAssignment::AgentSelector
  pattr_initialize [:inbox!, :conversation]

  def select(members)
    tier_pools(inbox_members_for(Array(members))).each do |pool|
      next if pool.blank?

      agent = order_selector.select_agent(pool)
      return agent if agent
    end

    nil
  end

  private

  def inbox_members_for(members)
    return members if members.all?(InboxMember)
    return [] if members.blank?

    inbox.inbox_members.where(user_id: members.map { |member| member_user_id(member) }).includes(:user).to_a
  end

  def tier_pools(members)
    return [members] unless tiers_enabled?

    grouped = members.group_by { |member| tier_for(member_user_id(member)) }
    [grouped['primary'] || [], grouped['backup'] || []]
  end

  def tiers_enabled?
    team = conversation&.team
    team.present? && team.assignment_tiers_enabled?
  end

  def tier_for(user_id)
    value = tiers_by_user_id[user_id]
    return 'backup' if value == 'backup' || value == TeamMember.assignment_tiers[:backup]

    'primary'
  end

  def tiers_by_user_id
    @tiers_by_user_id ||= conversation.team.team_members.pluck(:user_id, :assignment_tier).to_h
  end

  def member_user_id(member)
    member.is_a?(User) ? member.id : member.user_id
  end

  def order_selector
    policy = inbox.assignment_policy
    return AutoAssignment::LeastBusySelector.new(inbox: inbox) if policy&.least_busy?

    if policy.respond_to?(:balanced?) && policy.balanced? && inbox.account.feature_enabled?('advanced_assignment')
      return Enterprise::AutoAssignment::BalancedSelector.new(inbox: inbox)
    end

    AutoAssignment::RoundRobinSelector.new(inbox: inbox)
  end
end
