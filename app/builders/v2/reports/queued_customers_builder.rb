class V2::Reports::QueuedCustomersBuilder
  attr_reader :account, :params

  def initialize(account, params = {})
    @account = account
    @params = params
  end

  def build
    {
      summary: summary_metrics,
      waiting_time: waiting_time_metrics,
      daily: daily_metrics,
      heatmap: heatmap_metrics
    }
  end

  private

  def scoped_conversations
    scope = Conversation.where(account_id: account.id)
    scope = scope.where(team_id: params[:team_ids]) if params[:team_ids].present?
    scope = scope.where(inbox_id: params[:inbox_ids]) if params[:inbox_ids].present?
    scope
  end

  def scoped_queue_entries
    scope = ConversationQueue
            .for_account(account.id)
            .where(conversation_id: scoped_conversations.select(:id))
    scope.where(queued_at: since_time..until_time)
  end

  def since_time
    @since_time ||= Time.zone.at(params[:since].to_i)
  end

  def until_time
    @until_time ||= Time.zone.at(params[:until].to_i)
  end

  def summary_metrics
    queued = scoped_queue_entries.count
    entered = scoped_queue_entries.assigned.count
    left = scoped_queue_entries.left.count

    {
      queued_customers: queued,
      entered_chat: {
        value: entered,
        percentage: percentage(entered, queued)
      },
      left_queue: {
        value: left,
        percentage: percentage(left, queued)
      }
    }
  end

  def waiting_time_metrics
    {
      time_to_enter_chat: average_wait_time_for(:assigned, :assigned_at),
      time_to_leave_queue: average_wait_time_for(:left, :left_at)
    }
  end

  def average_wait_time_for(status, end_column)
    scoped_queue_entries
      .public_send(status)
      .where.not(end_column => nil)
      .average("EXTRACT(EPOCH FROM (#{end_column} - queued_at))")
      .to_f
      .round
  end

  def daily_metrics
    scoped_queue_entries
      .select(*daily_metrics_select_columns)
      .group('DATE(queued_at)')
      .order('metric_date ASC')
      .map { |row| daily_metrics_row(row) }
  end

  def daily_metrics_select_columns
    assigned_status = ConversationQueue.statuses[:assigned]
    left_status = ConversationQueue.statuses[:left]

    [
      'DATE(queued_at) AS metric_date',
      'COUNT(*) AS queued_customers',
      "COUNT(*) FILTER (WHERE status = #{assigned_status}) AS entered_chat",
      "COUNT(*) FILTER (WHERE status = #{left_status}) AS left_queue",
      avg_wait_select('assigned_at', assigned_status, 'time_to_enter_chat'),
      avg_wait_select('left_at', left_status, 'time_to_leave_queue')
    ]
  end

  def avg_wait_select(end_column, status, alias_name)
    <<~SQL.squish
      AVG(EXTRACT(EPOCH FROM (#{end_column} - queued_at)))
      FILTER (WHERE status = #{status} AND #{end_column} IS NOT NULL) AS #{alias_name}
    SQL
  end

  def daily_metrics_row(row)
    {
      date: row.metric_date.to_s,
      queued_customers: row.queued_customers.to_i,
      entered_chat: row.entered_chat.to_i,
      left_queue: row.left_queue.to_i,
      time_to_enter_chat: row.time_to_enter_chat.to_f.round,
      time_to_leave_queue: row.time_to_leave_queue.to_f.round
    }
  end

  def heatmap_metrics
    grouped = scoped_queue_entries
              .group("DATE_TRUNC('hour', queued_at)")
              .count
              .transform_keys { |time| time.beginning_of_hour.to_i }

    current_hour = since_time.beginning_of_hour
    end_hour = until_time.beginning_of_hour
    rows = []

    while current_hour <= end_hour
      rows << {
        timestamp: current_hour.to_i,
        value: grouped[current_hour.to_i] || 0
      }
      current_hour += 1.hour
    end

    rows
  end

  def percentage(value, total)
    return 0 if total.to_i.zero?

    ((value.to_f / total) * 100).round(2)
  end
end
