module Filters::AssigneeFilterHelper
  def default_filter(query_hash, filter_operator_value)
    if query_hash[:attribute_key] == 'assignee_id' && query_hash[:filter_operator].in?(%w[is_present is_not_present])
      return assignee_presence_filter(filter_config[:table_name], query_hash)
    end

    return assignee_with_unassigned_filter(query_hash, filter_operator_value) if assignee_with_unassigned?(query_hash)

    "#{filter_config[:table_name]}.#{query_hash[:attribute_key]} #{filter_operator_value} #{query_hash[:query_operator]}"
  end

  def assignee_with_unassigned?(query_hash)
    query_hash[:attribute_key] == 'assignee_id' &&
      Array.wrap(query_hash['values']).any? { |value| value.to_s == FilterService::UNASSIGNED_VALUE }
  end

  # `unassigned` is not an agent id, so it is matched through the assignee columns instead of the IN list.
  def assignee_with_unassigned_filter(query_hash, filter_operator_value)
    table_name = filter_config[:table_name]
    assignee_in = "#{table_name}.assignee_id #{filter_operator_value.delete_prefix('NOT ')}"

    if query_hash[:filter_operator] == 'equal_to'
      "(#{assignee_in} OR (#{table_name}.assignee_id IS NULL AND #{table_name}.assignee_agent_bot_id IS NULL)) #{query_hash[:query_operator]}"
    else
      "(#{table_name}.assignee_id IS NOT NULL AND NOT COALESCE(#{assignee_in}, FALSE)) #{query_hash[:query_operator]}"
    end
  end

  # Assignee ownership can live in either column until it is standardized as a polymorphic association.
  def assignee_presence_filter(table_name, query_hash)
    if query_hash[:filter_operator] == 'is_present'
      return "(#{table_name}.assignee_id IS NOT NULL OR #{table_name}.assignee_agent_bot_id IS NOT NULL) #{query_hash[:query_operator]}"
    end

    "(#{table_name}.assignee_id IS NULL AND #{table_name}.assignee_agent_bot_id IS NULL) #{query_hash[:query_operator]}"
  end
end
