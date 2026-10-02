module ReportBotMetricsHelper
  private

  def bot_first_response_time
    get_grouped_values(scope.reporting_events.where(name: 'bot_first_response', account_id: account.id))
  end

  def bot_first_response_time_summary
    reporting_events = scope.reporting_events.where(name: 'bot_first_response', account_id: account.id, created_at: range)
    first_response_time = params[:business_hours] ? reporting_events.average(:value_in_business_hours) : reporting_events.average(:value)
    first_response_time.presence || 0
  end

  def bot_reply_time
    grouped_reporting_events = get_grouped_values(scope.reporting_events.where(name: 'bot_reply_time', account_id: account.id))
    return grouped_reporting_events.average(:value_in_business_hours) if params[:business_hours]

    grouped_reporting_events.average(:value)
  end

  def bot_reply_time_summary
    reporting_events = scope.reporting_events.where(name: 'bot_reply_time', account_id: account.id, created_at: range)
    reply_time = params[:business_hours] ? reporting_events.average(:value_in_business_hours) : reporting_events.average(:value)
    reply_time.presence || 0
  end

  def agent_chat_duration
    return 0 unless params[:type].to_sym == :agent

    scope.reporting_events.where(name: :agent_chat_duration, account_id: account.id, created_at: range).average(:value) || 0
  end

  def agent_chat_duration_summary
    return 0 unless params[:type].to_sym == :agent

    scope.reporting_events.where(name: :agent_chat_duration, account_id: account.id, created_at: range).average(:value) || 0
  end
end
