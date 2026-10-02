class V2::Reports::InboxSummaryBuilder < V2::Reports::BaseSummaryBuilder
  pattr_initialize [:account!, :params!]

  def build
    load_data
    prepare_report
  end

  private

  attr_reader :conversations_count, :resolved_count,
              :avg_resolution_time, :avg_first_response_time, :avg_reply_time, :csat_satisfaction_score

  def prepare_report
    inboxes_for_report.map { |inbox| build_inbox_stats(inbox) }
  end

  def inboxes_for_report
    scope = account.inboxes
    inbox_ids = compact_ids(:inbox_ids)
    return scope.where(id: inbox_ids) if inbox_ids
    return scope if secondary_filters_blank?

    entity_ids = summary_entity_ids(
      conversations_count, resolved_count, avg_resolution_time,
      avg_first_response_time, avg_reply_time, csat_satisfaction_score
    )
    return [] if entity_ids.empty?

    scope.where(id: entity_ids)
  end

  def secondary_filters_blank?
    compact_ids(:user_ids).blank? && compact_ids(:team_ids).blank? && compact_ids(:label_ids).blank?
  end

  def build_inbox_stats(inbox)
    {
      id: inbox.id,
      conversations_count: conversations_count[inbox.id] || 0,
      resolved_conversations_count: resolved_count[inbox.id] || 0,
      avg_resolution_time: avg_resolution_time[inbox.id],
      avg_first_response_time: avg_first_response_time[inbox.id],
      avg_reply_time: avg_reply_time[inbox.id],
      csat_satisfaction_score: csat_satisfaction_score[inbox.id] || 0
    }
  end

  def apply_csat_filters(scope)
    scope = scope.joins(:conversation)
    scope = apply_csat_inbox_filter(scope)
    scope = apply_csat_user_filter(scope)
    scope = apply_csat_team_filter(scope)
    apply_csat_label_filter(scope)
  end

  def apply_csat_inbox_filter(scope)
    inbox_ids = compact_ids(:inbox_ids)
    return scope if inbox_ids.blank?

    scope.where(conversations: { inbox_id: inbox_ids })
  end

  def apply_csat_user_filter(scope)
    user_ids = compact_ids(:user_ids)
    return scope if user_ids.blank?

    scope.where(conversations: { assignee_id: user_ids })
  end

  def apply_csat_team_filter(scope)
    team_ids = compact_ids(:team_ids)
    return scope if team_ids.blank?

    scope.where(conversations: { team_id: team_ids })
  end

  def csat_group_by_key
    'conversations.inbox_id'
  end

  def group_by_key
    :inbox_id
  end
end
