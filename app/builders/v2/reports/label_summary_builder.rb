class V2::Reports::LabelSummaryBuilder < V2::Reports::BaseSummaryBuilder
  attr_reader :account, :params

  # rubocop:disable Lint/MissingSuper
  def initialize(account:, params:)
    @account = account
    @params = params
    (params[:timezone_offset] || 0).to_f
    @timezone = 'UTC'
  end
  # rubocop:enable Lint/MissingSuper

  def build
    report_data = collect_report_data
    label_names = label_names_from_report(report_data)
    return [] if label_names.empty?

    labels_for_report(label_names).map { |label| build_label_report(label, report_data) }
  end

  def label_names_from_report(report_data)
    report_data.values.flat_map(&:keys).compact.uniq
  end

  def labels_for_report(label_names)
    scope = account.labels.where(title: label_names)
    scope = scope.where(id: params[:label_ids].reject(&:blank?)) if params[:label_ids].present?
    scope.to_a
  end

  private

  def collect_report_data
    conversation_filter = build_conversation_filter
    use_business_hours = use_business_hours?

    {
      conversation_counts: fetch_conversation_counts(conversation_filter),
      resolved_counts: fetch_resolved_counts,
      resolution_metrics: fetch_metrics(conversation_filter, 'conversation_resolved', use_business_hours),
      first_response_metrics: fetch_metrics(conversation_filter, 'first_response', use_business_hours),
      reply_metrics: fetch_metrics(conversation_filter, 'reply_time', use_business_hours),
      csat_scores: fetch_csat_scores
    }
  end

  def build_label_report(label, report_data)
    {
      id: label.id,
      name: label.title,
      conversations_count: report_data[:conversation_counts][label.title] || 0,
      avg_resolution_time: report_data[:resolution_metrics][label.title] || 0,
      avg_first_response_time: report_data[:first_response_metrics][label.title] || 0,
      avg_reply_time: report_data[:reply_metrics][label.title] || 0,
      resolved_conversations_count: report_data[:resolved_counts][label.title] || 0,
      csat_satisfaction_score: report_data[:csat_scores][label.title] || 0
    }
  end

  def fetch_csat_scores
    scope = labeled_csat_scope.where.not(rating: nil)
    scope = scope.where(assigned_agent_id: params[:user_ids].reject(&:blank?)) if params[:user_ids].present?
    scope = restrict_to_selected_labels(scope)

    scope.select('tags.name', 'COUNT(*) as total_count', 'SUM(rating) as rating_sum')
         .group('tags.name')
         .each_with_object({}) do |record, hash|
      hash[record.name] = csat_score_percent(record)
    end
  end

  def csat_score_percent(record)
    total = record.total_count.to_f
    return 0 unless total.positive?

    ((record.rating_sum.to_f / total) * 20).round(2)
  end

  def labeled_csat_scope
    CsatSurveyResponse
      .joins(conversation: { taggings: :tag })
      .where(created_at: range, conversations: build_conversation_filter, taggings: label_tagging_scope)
  end

  def label_tagging_scope
    { taggable_type: 'Conversation', context: 'labels' }
  end

  def restrict_to_selected_labels(scope)
    tag_ids = selected_tag_ids
    return scope if tag_ids.nil?
    return scope.none if tag_ids.empty?

    scope.where(taggings: { tag_id: tag_ids })
  end

  def restrict_tag_ids(scope)
    tag_ids = selected_tag_ids
    return scope if tag_ids.nil?
    return scope.none if tag_ids.empty?

    scope.where(tag_id: tag_ids)
  end

  def selected_tag_ids
    return if params[:label_ids].blank?

    ReportingEvent.tag_ids_for_labels(params[:label_ids].reject(&:blank?), account.id)
  end

  def use_business_hours?
    ActiveModel::Type::Boolean.new.cast(params[:business_hours])
  end

  def build_conversation_filter
    {
      account_id: account.id,
      created_at: range.presence,
      assignee_id: params[:user_ids]&.reject(&:blank?).presence,
      inbox_id: params[:inbox_ids]&.reject(&:blank?).presence,
      team_id: params[:team_ids]&.reject(&:blank?).presence
    }.compact
  end

  def fetch_conversation_counts(conversation_filter)
    fetch_counts(conversation_filter)
  end

  def fetch_resolved_counts
    labeled_reporting_events('conversation_resolved')
      .group('tags.name')
      .count('DISTINCT reporting_events.id')
  end

  def fetch_counts(conversation_filter)
    ActsAsTaggableOn::Tagging
      .joins('INNER JOIN conversations ON taggings.taggable_id = conversations.id')
      .joins('INNER JOIN tags ON taggings.tag_id = tags.id')
      .where(
        taggable_type: 'Conversation',
        context: 'labels',
        conversations: conversation_filter
      ).then { |scope| restrict_tag_ids(scope) }
      .select('tags.name, COUNT(DISTINCT taggings.taggable_id) AS count')
      .group('tags.name')
      .each_with_object({}) { |record, hash| hash[record.name] = record.count }
  end

  def fetch_metrics(conversation_filter, event_name, use_business_hours)
    labeled_reporting_events(event_name, conversation_filter)
      .group('tags.name')
      .order('tags.name')
      .select('tags.name', avg_metric_select(use_business_hours))
      .each_with_object({}) { |record, hash| hash[record.name] = record.avg_value.to_f }
  end

  def labeled_reporting_events(event_name, conversation_filter = build_conversation_filter)
    scope = ReportingEvent
            .joins(conversation: { taggings: :tag })
            .where(name: event_name, conversations: conversation_filter, taggings: label_tagging_scope)
    apply_reporting_event_filters(scope)
  end

  def apply_reporting_event_filters(scope)
    scope = scope.where(user_id: params[:user_ids]&.reject(&:blank?)) if params[:user_ids].present?
    scope = scope.where(inbox_id: params[:inbox_ids]&.reject(&:blank?)) if params[:inbox_ids].present?
    restrict_to_selected_labels(scope)
  end

  def avg_metric_select(use_business_hours)
    column = use_business_hours ? 'reporting_events.value_in_business_hours' : 'reporting_events.value'
    "AVG(#{column}) as avg_value"
  end
end
