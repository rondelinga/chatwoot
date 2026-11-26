class ChatQueue::ForceTransferService
  pattr_initialize [:conversation!, :current_user!]

  def perform
    target = least_loaded_agent
    return unavailable unless target

    message = transfer_to(target)
    { success: true, agent: target, message: message.push_event_data }
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: conversation.account).capture_exception
    { success: false, agent: nil }
  end

  private

  # Online inbox collaborators under the limit. A conversation that already has a
  # team stays inside that team; one without a team stays inside the inbox.
  def least_loaded_agent
    agents = available_agents
    return if agents.blank?

    counts = open_counts(agents.map(&:id))
    assigned_at = last_assigned_at(agents.map(&:id))
    agents.min_by do |agent|
      [counts.fetch(agent.id, 0), assigned_at.fetch(agent.id, Time.zone.at(0))]
    end
  end

  def available_agents
    User.where(id: online_agent_ids).select do |agent|
      agent.id != conversation.assignee_id &&
        permissions.allowed?(conversation, agent) &&
        availability.available?(agent)
    end
  end

  def online_agent_ids
    (OnlineStatusTracker.get_available_users(conversation.account_id) || {})
      .select { |_id, status| status == 'online' }
      .keys
      .map(&:to_i)
  end

  def open_counts(agent_ids)
    Conversation.where(account_id: conversation.account_id, assignee_id: agent_ids, status: :open)
                .group(:assignee_id)
                .count
  end

  def last_assigned_at(agent_ids)
    Conversation.where(account_id: conversation.account_id, assignee_id: agent_ids)
                .group(:assignee_id)
                .maximum(:updated_at)
  end

  def transfer_to(agent)
    Rails.logger.info(
      "[FORCE_TRANSFER] account=#{conversation.account_id} conversation=#{conversation.id} " \
      "to=#{agent.id} by=#{current_user&.id}"
    )

    from_agent = nil
    Conversation.transaction do
      locked = Conversation.lock.find(conversation.id)
      from_agent = locked.assignee
      locked.instance_variable_set(:@skip_assignee_activity, true)
      ChatQueue::QueueService.new(account: locked.account).remove_from_queue(locked)
      locked.update!(assignee: agent, status: :open)
    end

    # Created after the lock commits, so message.created is broadcast on its own
    # and the open thread can render it without a reload.
    create_transfer_activity(from_agent, agent)
  end

  def create_transfer_activity(from_agent, to_agent)
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: I18n.t(
        'conversations.activity.force_transfer.transferred',
        from_name: from_agent&.name,
        to_name: to_agent.name
      )
    )
  end

  def unavailable
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: I18n.t(unavailable_key)
    )
    { success: false, agent: nil }
  end

  def unavailable_key
    if conversation.team_id.present?
      'conversations.activity.force_transfer.unavailable'
    else
      'conversations.activity.force_transfer.unavailable_inbox'
    end
  end

  def permissions
    @permissions ||= ChatQueue::Agents::PermissionsService.new(account: conversation.account)
  end

  def availability
    @availability ||= ChatQueue::Agents::AvailabilityService.new(account: conversation.account)
  end
end
