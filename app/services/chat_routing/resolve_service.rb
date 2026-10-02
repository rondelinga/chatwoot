class ChatRouting::ResolveService
  Result = Struct.new(:team_id, :bot_id, :routing_type_name, :matched_by_default)

  pattr_initialize [:inbox_id!, :account_id!, :contact_custom_attributes]

  def perform
    routing_type = find_routing_type
    matched_team = matching_by_routing_type(routing_type)
    inbox_team = matched_team || default_inbox_team

    return Result.new(nil, nil, nil, false) if inbox_team.blank?

    matched_by_default = matched_team.blank?
    routing_name = matched_by_default ? nil : routing_type&.name

    Result.new(inbox_team.team_id, inbox_team.agent_bot_id, routing_name, matched_by_default)
  end

  private

  def matching_by_routing_type(routing_type)
    return if routing_type.blank?

    InboxTeam.find_by(inbox_id: inbox_id, routing_type_id: routing_type.id)
  end

  def default_inbox_team
    InboxTeam.find_by(inbox_id: inbox_id, is_default: true)
  end

  def find_routing_type
    attrs = contact_custom_attributes || {}
    return if attrs.blank?

    RoutingType.where(account_id: account_id).detect do |rt|
      attribute_value_matches?(attrs[rt.attribute_key], rt.attribute_value)
    end
  end

  def attribute_value_matches?(contact_value, routing_value)
    return false if contact_value.nil?

    if boolean_attribute_value?(contact_value, routing_value)
      ActiveModel::Type::Boolean.new.cast(contact_value) ==
        ActiveModel::Type::Boolean.new.cast(routing_value)
    else
      contact_value.to_s == routing_value.to_s
    end
  end

  def boolean_attribute_value?(contact_value, routing_value)
    contact_value.in?([true, false]) ||
      routing_value.to_s.match?(/\A(true|false)\z/i)
  end
end
