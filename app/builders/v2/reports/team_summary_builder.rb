class V2::Reports::TeamSummaryBuilder < V2::Reports::BaseSummaryBuilder
  pattr_initialize [:account!, :params!]

  def build
    load_data
    prepare_report
  end

  private

  attr_reader :conversations_count, :resolved_count,
              :avg_resolution_time, :avg_first_response_time, :avg_reply_time, :csat_satisfaction_score

  def prepare_report
    scope = account.teams

    if params[:team_ids].present? && params[:team_ids].reject(&:blank?).any?
      scope = scope.where(id: params[:team_ids].reject(&:blank?))
    else
      if params[:user_ids].present? || params[:inbox_ids].present? || params[:label_ids].present?
        all_team_ids = [
          conversations_count.keys,
          resolved_count.keys,
          avg_resolution_time.keys,
          avg_first_response_time.keys,
          avg_reply_time.keys,
          csat_satisfaction_score.keys
        ].flatten.compact.uniq

        return [] if all_team_ids.empty?
        scope = scope.where(id: all_team_ids)
      end
    end

    scope.map do |team|
      build_team_stats(team)
    end
  end

  def build_team_stats(team)
    {
      id: team.id,
      conversations_count: conversations_count[team.id] || 0,
      resolved_conversations_count: resolved_count[team.id] || 0,
      avg_resolution_time: avg_resolution_time[team.id],
      avg_first_response_time: avg_first_response_time[team.id],
      avg_reply_time: avg_reply_time[team.id],
      csat_satisfaction_score: csat_satisfaction_score[team.id] || 0
    }
  end

  def apply_csat_filters(scope)
    scope = scope.joins(:conversation)
    scope = apply_csat_team_filter(scope)
    scope = apply_csat_user_filter(scope)
    scope = apply_csat_inbox_filter(scope)
    apply_csat_label_filter(scope)
  end

  def apply_csat_team_filter(scope)
    return scope if params[:team_ids].blank?

    scope.where(conversations: { team_id: params[:team_ids].reject(&:blank?) })
  end

  def apply_csat_user_filter(scope)
    return scope if params[:user_ids].blank?

    scope.where(assigned_agent_id: params[:user_ids].reject(&:blank?))
  end

  def apply_csat_inbox_filter(scope)
    return scope if params[:inbox_ids].blank?

    scope.where(conversations: { inbox_id: params[:inbox_ids].reject(&:blank?) })
  end

  def apply_csat_label_filter(scope)
    return scope if params[:label_ids].blank?

    tag_ids = ReportingEvent.tag_ids_for_labels(params[:label_ids].reject(&:blank?), account.id)
    return scope if tag_ids.empty?

    scope.joins(conversation_labels_join_clause).where(taggings: { tag_id: tag_ids })
  end

  def conversation_labels_join_clause
    <<~SQL.squish
      INNER JOIN taggings
        ON taggings.taggable_id = conversations.id
        AND taggings.taggable_type = 'Conversation'
        AND taggings.context = 'labels'
    SQL
  end

  def csat_group_by_key
    'conversations.team_id'
  end

  def group_by_key
    'conversations.team_id'
  end
end
