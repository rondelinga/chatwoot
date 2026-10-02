module Api::V2::Accounts::ReportsMetricsHelper
  private

  def generate_readable_report_metrics(report)
    [
      report[:conversations_count],
      format_time(report[:avg_first_response_time]),
      format_time(report[:avg_resolution_time]),
      format_time(report[:avg_reply_time]),
      report[:resolved_conversations_count],
      format_time(report[:agent_chat_duration]),
      format_csat_score(report[:csat_satisfaction_score])
    ]
  end

  def generate_conversation_report_metrics(summary)
    [
      summary[:conversations_count],
      summary[:incoming_messages_count],
      summary[:outgoing_messages_count],
      format_time(summary[:avg_first_response_time]),
      format_time(summary[:avg_resolution_time]),
      summary[:resolutions_count],
      format_time(summary[:reply_time])
    ]
  end

  def format_time(value)
    Reports::TimeFormatPresenter.new(value).format
  end

  def format_csat_score(score)
    score ? "#{score}%" : '--'
  end

  def format_date_range
    { since: Time.zone.at(params[:since].to_i), until: Time.zone.at(params[:until].to_i) }
  end
end
