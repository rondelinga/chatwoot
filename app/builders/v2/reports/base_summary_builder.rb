class V2::Reports::BaseSummaryBuilder
  include DateRangeHelper

  def build
    load_data
    prepare_report
  end

  private

  def load_data
    results = data_source.summary

    @conversations_count = results.transform_values { |data| data[:conversations_count] }
    @resolved_count = results.transform_values { |data| data[:resolved_conversations_count] }
    @avg_resolution_time = results.transform_values { |data| data[:avg_resolution_time] }
    @avg_first_response_time = results.transform_values { |data| data[:avg_first_response_time] }
    @avg_reply_time = results.transform_values { |data| data[:avg_reply_time] }
    @agent_chat_duration = results.transform_values { |data| data[:agent_chat_duration] }
    @csat_satisfaction_score = fetch_csat_satisfaction_score
  end

  def filter_by_team(scope)
    scope.joins(:conversation).where(conversations: { team_id: compact_ids(:team_ids) })
  end

  def fetch_csat_satisfaction_score
    scope = filtered_csat_responses
            .select(csat_group_by_field, csat_select_fields)
            .group(csat_group_by_key)

    scope.each_with_object({}) do |record, hash|
      key = record.public_send(csat_group_key_name)
      total = record.total_count.to_f
      positive = record.positive_count.to_f

      hash[key] = total.positive? ? ((positive / total) * 100).round(2) : 0
    end
  end

  def filtered_csat_responses
    scope = account.csat_survey_responses.where(created_at: range).where.not(rating: nil)
    apply_csat_filters(scope)
  end

  def apply_csat_filters(scope)
    scope
  end

  def conversation_labels_join_clause
    <<~SQL.squish
      INNER JOIN taggings
        ON taggings.taggable_id = conversations.id
        AND taggings.taggable_type = 'Conversation'
        AND taggings.context = 'labels'
    SQL
  end

  def apply_csat_label_filter(scope)
    label_ids = compact_ids(:label_ids)
    return scope if label_ids.blank?

    tag_ids = ReportingEvent.tag_ids_for_labels(label_ids, account.id)
    return scope if tag_ids.empty?

    scope.joins(conversation_labels_join_clause).where(taggings: { tag_id: tag_ids })
  end

  def summary_entity_ids(*metrics)
    metrics.flat_map(&:keys).compact.uniq
  end

  def csat_select_fields
    <<-SQL.squish
      COUNT(*) as total_count,
      COUNT(CASE WHEN rating IN (4, 5) THEN 1 END) as positive_count
    SQL
  end

  def csat_group_by_key
    # Override this method
  end

  def csat_group_by_field
    csat_group_by_key
  end

  def csat_group_key_name
    csat_group_by_key.to_s.split('.').last.to_sym
  end

  def group_by_key
    # Override this method
  end

  def prepare_report
    # Override this method
  end

  def data_source
    @data_source ||= Reports::DataSource.for(
      account: account,
      metric: nil,
      dimension_type: summary_dimension_type,
      dimension_id: nil,
      scope: nil,
      range: range,
      group_by: 'day',
      timezone_offset: params[:timezone_offset],
      business_hours: params[:business_hours],
      user_ids: compact_ids(:user_ids),
      inbox_ids: compact_ids(:inbox_ids),
      team_ids: compact_ids(:team_ids),
      label_ids: compact_ids(:label_ids)
    )
  end

  def compact_ids(key)
    return if params[key].blank?

    Array(params[key]).reject(&:blank?)
  end

  def summary_dimension_type
    {
      'account_id' => 'account',
      'user_id' => 'agent',
      'inbox_id' => 'inbox',
      'conversations.team_id' => 'team'
    }.fetch(group_by_key.to_s)
  end
end
