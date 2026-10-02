module Reports::ReportMetricRegistry
  METRICS = {
    conversations_count: Reports::ReportMetric.build(name: :conversations_count, aggregate: :count),
    incoming_messages_count: Reports::ReportMetric.build(name: :incoming_messages_count, aggregate: :count),
    outgoing_messages_count: Reports::ReportMetric.build(name: :outgoing_messages_count, aggregate: :count),
    avg_first_response_time: Reports::ReportMetric.build(
      name: :avg_first_response_time, aggregate: :average, raw_event_name: :first_response,
      rollup_metric: :first_response, summary_key: :avg_first_response_time
    ),
    avg_resolution_time: Reports::ReportMetric.build(
      name: :avg_resolution_time, aggregate: :average, raw_event_name: :conversation_resolved,
      rollup_metric: :resolution_time, summary_key: :avg_resolution_time
    ),
    reply_time: Reports::ReportMetric.build(
      name: :reply_time, aggregate: :average, raw_event_name: :reply_time,
      rollup_metric: :reply_time, summary_key: :avg_reply_time
    ),
    avg_resolution_time_without_bot: Reports::ReportMetric.build(
      name: :avg_resolution_time_without_bot, aggregate: :average, raw_event_name: :conversation_resolved,
      rollup_metric: :resolution_time_without_bot, summary_key: :avg_resolution_time_without_bot
    ),
    agent_chat_duration: Reports::ReportMetric.build(
      name: :agent_chat_duration, aggregate: :average, raw_event_name: :agent_chat_duration,
      rollup_metric: :agent_chat_duration, summary_key: :agent_chat_duration
    ),
    resolutions_count: Reports::ReportMetric.build(
      name: :resolutions_count, aggregate: :count, raw_event_name: :conversation_resolved,
      rollup_metric: :resolutions_count, summary_key: :resolved_conversations_count
    ),
    bot_resolutions_count: Reports::ReportMetric.build(
      name: :bot_resolutions_count, aggregate: :count, raw_event_name: :conversation_bot_resolved,
      rollup_metric: :bot_resolutions_count, raw_count_strategy: :exclude_bot_handoffs
    ),
    bot_handoffs_count: Reports::ReportMetric.build(
      name: :bot_handoffs_count, aggregate: :count, raw_event_name: :conversation_bot_handoff,
      rollup_metric: :bot_handoffs_count, raw_count_strategy: :distinct_conversation
    )
  }.freeze

  SUMMARY_METRIC_NAMES = %i[resolutions_count avg_resolution_time avg_first_response_time reply_time].freeze

  module_function

  def fetch(name)
    return if name.blank?

    METRICS[name.to_sym]
  end

  def supported?(name)
    fetch(name).present?
  end

  def rollup_supported?(name)
    fetch(name)&.rollup_supported? || false
  end

  def summary_metrics
    SUMMARY_METRIC_NAMES.map { |metric_name| METRICS.fetch(metric_name) }
  end
end
