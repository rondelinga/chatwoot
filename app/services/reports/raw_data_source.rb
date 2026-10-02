class Reports::RawDataSource < Reports::DataSource
  include Reports::RawSummaryQueries
  def timeseries
    average_metric? ? average_timeseries : count_timeseries
  end

  def aggregate
    average_metric? ? average_scope.average(average_value_key) : count_scope.count
  end

  def summary
    metric_results = summary_scope
                     .select(*summary_select_fields)
                     .group(summary_group_by_key)
                     .index_by { |record| record.public_send(summary_index_key) }

    merge_summary_results(metric_results, summary_conversation_counts)
  end

  private

  def count_timeseries
    grouped_count.map do |event_date, event_count|
      { value: event_count, timestamp: event_date.in_time_zone(timezone).to_i }
    end
  end

  def average_timeseries
    grouped_average_time = grouped_average_scope.average(average_value_key)
    grouped_event_count = grouped_average_scope.count

    grouped_average_time.each_with_object([]) do |(event_date, average_time), results|
      results << {
        value: average_time,
        timestamp: event_date.in_time_zone(timezone).to_i,
        count: grouped_event_count[event_date]
      }
    end
  end

  def grouped_average_scope
    average_scope.group_by_period(
      group_by,
      :created_at,
      default_value: 0,
      range: range,
      permit: %w[day week month year hour],
      time_zone: timezone
    )
  end

  def grouped_count
    count_scope.group_by_period(
      group_by,
      :created_at,
      default_value: 0,
      range: range,
      permit: %w[day week month year hour],
      time_zone: timezone
    ).count
  end

  def account_scope?
    dimension_type == 'account'
  end

  def average_scope
    events = scope.reporting_events.where(name: raw_event_name, created_at: range, account_id: account.id)
    return events unless account_scope?

    events = events.joins(:conversation).where(conversations: { inbox_id: filtered_inbox_ids }) if filtered_inbox_ids.present?
    events = events.where(user_id: filtered_user_ids) if filtered_user_ids.present?
    events
  end

  def count_scope
    case metric.to_s
    when 'conversations_count'
      conversations = scope.conversations.where(account_id: account.id, created_at: range)
      return conversations unless account_scope?

      conversations = conversations.where(inbox_id: filtered_inbox_ids) if filtered_inbox_ids.present?
      conversations = conversations.where(assignee_id: filtered_user_ids) if filtered_user_ids.present?
      conversations
    when 'incoming_messages_count'
      message_count_scope(:incoming)
    when 'outgoing_messages_count'
      message_count_scope(:outgoing)
    else
      reporting_event_count_scope
    end
  end

  def message_count_scope(direction)
    messages = scope.messages.where(account_id: account.id, created_at: range).public_send(direction).unscope(:order)
    return messages unless account_scope?

    messages = messages.where(inbox_id: filtered_inbox_ids) if filtered_inbox_ids.present?
    messages = messages.joins(:conversation).where(conversations: { assignee_id: filtered_user_ids }) if filtered_user_ids.present?
    messages
  end

  def reporting_event_count_scope
    events = scope.reporting_events.where(
      name: raw_event_name,
      account_id: account.id,
      created_at: range
    )
    events = apply_account_event_filters(events)

    return events.where.not(conversation_id: bot_handoff_conversation_ids_subquery) if raw_count_strategy == :exclude_bot_handoffs
    return events unless raw_count_strategy == :distinct_conversation

    events.select(:conversation_id).distinct
  end

  def apply_account_event_filters(events)
    return events unless account_scope?
    return events if filtered_inbox_ids.blank? && filtered_user_ids.blank?

    events = events.joins(:conversation)
    events = events.where(conversations: { inbox_id: filtered_inbox_ids }) if filtered_inbox_ids.present?
    events = events.where(conversations: { assignee_id: filtered_user_ids }) if filtered_user_ids.present?
    events
  end

  def filtered_inbox_ids
    Array(inbox_ids).reject(&:blank?)
  end

  def filtered_user_ids
    Array(user_ids).reject(&:blank?)
  end

  def bot_handoff_conversation_ids_subquery
    scope.reporting_events.where(
      name: :conversation_bot_handoff,
      account_id: account.id,
      created_at: range
    ).where.not(conversation_id: nil).select(:conversation_id)
  end

  def average_value_key
    use_business_hours? ? :value_in_business_hours : :value
  end
end
