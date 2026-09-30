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
    scope = account.inboxes

    if params[:inbox_ids].present? && params[:inbox_ids].reject(&:blank?).any?
      scope = scope.where(id: params[:inbox_ids].reject(&:blank?))
    else
      if params[:user_ids].present? || params[:team_ids].present? || params[:label_ids].present?
        all_inbox_ids = [
          conversations_count.keys,
          resolved_count.keys,
          avg_resolution_time.keys,
          avg_first_response_time.keys,
          avg_reply_time.keys,
          csat_satisfaction_score.keys
        ].flatten.compact.uniq

        return [] if all_inbox_ids.empty?
        scope = scope.where(id: all_inbox_ids)
      end
    end

    scope.map do |inbox|
      build_inbox_stats(inbox)
    end
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
    scope = scope.where(conversations: { inbox_id: params[:inbox_ids].reject(&:blank?) }) if params[:inbox_ids].present?
    scope = scope.where(conversations: { assignee_id: params[:user_ids].reject(&:blank?) }) if params[:user_ids].present?
    scope = scope.where(conversations: { team_id: params[:team_ids].reject(&:blank?) }) if params[:team_ids].present?
    
    if params[:label_ids].present?
      tag_ids = ReportingEvent.tag_ids_for_labels(params[:label_ids].reject(&:blank?), account.id)
      scope = scope.joins('INNER JOIN taggings ON taggings.taggable_id = conversations.id AND taggings.taggable_type = \'Conversation\' AND taggings.context = \'labels\'')
                   .where(taggings: { tag_id: tag_ids }) unless tag_ids.empty?
    end
    
    scope
  end

  def csat_group_by_key
    'conversations.inbox_id'
  end

  def group_by_key
    :inbox_id
  end
end
