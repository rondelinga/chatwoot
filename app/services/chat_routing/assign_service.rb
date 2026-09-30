class ChatRouting::AssignService
  pattr_initialize [:conversation!]

  def perform
    result = apply
    conversation.save! if conversation.persisted? && conversation.changed?
    create_activity_messages(result)
    result
  end

  def apply
    return empty_result if skip_routing?

    result = resolve
    apply_result(result)
    result
  end

  def create_activity_messages(result)
    return if result.blank?
    return if result.team_id.blank? && result.bot_id.blank?

    create_team_activity_message(result)
    create_bot_activity_message(result)
  end

  private

  def skip_routing?
    conversation.team_id.present? || conversation.inbox.blank? || !conversation.inbox.inbox_teams.exists?
  end

  def empty_result
    ChatRouting::ResolveService::Result.new(nil, nil, nil, false)
  end

  def resolve
    ChatRouting::ResolveService.new(
      inbox_id: conversation.inbox_id,
      account_id: conversation.account_id,
      contact_custom_attributes: conversation.contact&.custom_attributes
    ).perform
  end

  def apply_result(result)
    conversation.team_id = result.team_id if result.team_id.present?
    return if result.bot_id.blank?

    conversation.assignee_id = nil
    conversation.assignee_agent_bot_id = result.bot_id
  end

  def create_team_activity_message(result)
    return if result.team_id.blank?

    team = Team.find_by(id: result.team_id)
    return if team.blank?

    content = if result.matched_by_default
                I18n.t('conversations.activity.routing.team_assigned_default', team_name: team.name)
              else
                I18n.t('conversations.activity.routing.team_assigned_with_type',
                       team_name: team.name, routing_type_name: result.routing_type_name)
              end

    create_activity_message(content)
  end

  def create_bot_activity_message(result)
    return if result.bot_id.blank?

    bot = AgentBot.find_by(id: result.bot_id)
    return if bot.blank?

    content = if result.matched_by_default
                I18n.t('conversations.activity.routing.bot_assigned_default', bot_name: bot.name)
              else
                I18n.t('conversations.activity.routing.bot_assigned_with_type',
                       bot_name: bot.name, routing_type_name: result.routing_type_name)
              end

    create_activity_message(content)
  end

  def create_activity_message(content)
    conversation.messages.create!(
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: content
    )
  end
end
