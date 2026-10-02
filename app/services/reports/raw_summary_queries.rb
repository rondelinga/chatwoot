module Reports::RawSummaryQueries
  private

  def summary_scope
    events = account.reporting_events.where(created_at: range)
    events = events.filter_by_user_id(user_ids) if user_ids.present?
    events = events.filter_by_inbox_id(inbox_ids) if inbox_ids.present?
    events = events.filter_by_label_ids(label_ids, account.id) if label_ids.present?
    apply_team_filter(events)
  end

  def apply_team_filter(events)
    return events unless dimension_type == 'team' || team_ids.present?

    events = events.joins(:conversation)
    return events.where(conversations: { team_id: team_ids }) if team_ids.present?

    events
  end

  def summary_conversation_counts
    conversations = account.conversations.where(created_at: range)
    conversations = conversations.where(assignee_id: user_ids) if user_ids.present?
    conversations = conversations.where(inbox_id: inbox_ids) if inbox_ids.present?
    conversations = conversations.where(team_id: team_ids) if team_ids.present?
    conversations = conversations.filter_by_label_ids(label_ids, account.id) if label_ids.present?
    conversations.group(summary_conversation_group_by_key).count
  end

  def merge_summary_results(metric_results, conversation_counts)
    (metric_results.keys | conversation_counts.keys).each_with_object({}) do |dimension_id, results|
      record = metric_results[dimension_id]
      results[dimension_id] = summary_attributes_for(record, conversation_counts[dimension_id])
    end
  end

  def summary_select_fields
    ["#{summary_group_by_key} as #{summary_index_key}"] + summary_metrics.map { |definition| summary_select_field(definition) }
  end

  def summary_select_field(definition)
    if definition.name == :resolutions_count && dimension_type == 'inbox'
      "COUNT(DISTINCT CASE WHEN reporting_events.name = 'conversation_resolved' THEN reporting_events.conversation_id END) " \
        "as #{definition.summary_key}"
    elsif definition.count?
      "COUNT(CASE WHEN name = '#{definition.raw_event_name}' THEN 1 END) as #{definition.summary_key}"
    else
      "AVG(CASE WHEN name = '#{definition.raw_event_name}' THEN #{average_value_key} END) as #{definition.summary_key}"
    end
  end

  def summary_attributes_for(record, conversations_count = 0)
    summary_metrics.each_with_object({ conversations_count: conversations_count.to_i }) do |definition, attributes|
      value = record&.public_send(definition.summary_key)
      attributes[definition.summary_key] = definition.count? ? value.to_i : value
    end
  end

  def summary_group_by_key
    { 'account' => :account_id, 'agent' => :user_id, 'inbox' => :inbox_id, 'team' => 'conversations.team_id' }[dimension_type]
  end

  def summary_conversation_group_by_key
    { 'account' => :account_id, 'agent' => :assignee_id, 'inbox' => :inbox_id, 'team' => :team_id }[dimension_type]
  end

  def summary_index_key
    summary_group_by_key.to_s.split('.').last
  end
end
