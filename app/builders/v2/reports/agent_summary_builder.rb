class V2::Reports::AgentSummaryBuilder < V2::Reports::BaseSummaryBuilder
  pattr_initialize [:account!, :params!]

  def build
    load_data
    prepare_report
  end

  private

  attr_reader :conversations_count, :resolved_count,
              :avg_resolution_time, :avg_first_response_time, :avg_reply_time,
              :agent_chat_duration, :csat_satisfaction_score

  def load_data
    super
    @agent_chat_duration = fetch_agent_chat_duration
  end

  def fetch_conversations_count
    scope = account.conversations.where(created_at: range)
    scope = filter_conversations_by_params(scope)
    scope.group('assignee_id').count
  end

  def filter_conversations_by_params(scope)
    scope = scope.where(assignee_id: compact_ids(:user_ids)) if compact_ids(:user_ids)
    scope = scope.where(inbox_id: compact_ids(:inbox_ids)) if compact_ids(:inbox_ids)
    scope = scope.where(team_id: compact_ids(:team_ids)) if compact_ids(:team_ids)
    scope
  end

  def fetch_agent_chat_duration
    scope = account.reporting_events.where(name: :agent_chat_duration, created_at: range)
    scope = scope.filter_by_user_id(compact_ids(:user_ids)) if compact_ids(:user_ids)
    scope = scope.filter_by_inbox_id(compact_ids(:inbox_ids)) if compact_ids(:inbox_ids)
    scope = scope.filter_by_label_ids(compact_ids(:label_ids), account.id) if compact_ids(:label_ids)
    scope = filter_by_team(scope) if compact_ids(:team_ids)
    scope.group(:user_id).average(:value)
  end

  def prepare_report
    account_users_for_report.map { |account_user| build_agent_stats(account_user) }
  end

  def account_users_for_report
    scope = account.account_users
    user_ids = compact_ids(:user_ids)
    return scope.where(user_id: user_ids) if user_ids
    return scope if secondary_filters_blank?

    entity_ids = summary_entity_ids(
      conversations_count, resolved_count, avg_resolution_time,
      avg_first_response_time, avg_reply_time, agent_chat_duration, csat_satisfaction_score
    )
    return [] if entity_ids.empty?

    scope.where(user_id: entity_ids)
  end

  def secondary_filters_blank?
    compact_ids(:inbox_ids).blank? && compact_ids(:team_ids).blank? && compact_ids(:label_ids).blank?
  end

  def build_agent_stats(account_user)
    user_id = account_user.user_id
    {
      id: user_id,
      conversations_count: conversations_count[user_id] || 0,
      resolved_conversations_count: resolved_count[user_id] || 0,
      avg_resolution_time: avg_resolution_time[user_id],
      avg_first_response_time: avg_first_response_time[user_id],
      avg_reply_time: avg_reply_time[user_id],
      agent_chat_duration: (agent_chat_duration[user_id] || 0).to_i,
      csat_satisfaction_score: csat_satisfaction_score[user_id] || 0
    }
  end

  def apply_csat_filters(scope)
    scope = scope.where(assigned_agent_id: compact_ids(:user_ids)) if compact_ids(:user_ids)
    scope = scope.joins(:conversation)
    scope = apply_csat_inbox_filter(scope)
    scope = apply_csat_team_filter(scope)
    apply_csat_label_filter(scope)
  end

  def apply_csat_inbox_filter(scope)
    inbox_ids = compact_ids(:inbox_ids)
    return scope if inbox_ids.blank?

    scope.where(conversations: { inbox_id: inbox_ids })
  end

  def apply_csat_team_filter(scope)
    team_ids = compact_ids(:team_ids)
    return scope if team_ids.blank?

    scope.where(conversations: { team_id: team_ids })
  end

  def csat_group_by_key
    'csat_survey_responses.assigned_agent_id'
  end

  def group_by_key
    :user_id
  end
end
