class Api::V2::Accounts::ReportsController < Api::V1::Accounts::BaseController
  include Api::V2::Accounts::ReportsHelper
  include Api::V2::Accounts::HeatmapHelper
  include Api::V2::Accounts::ReportResponseFormatter
  include Api::V2::Accounts::ReportsDownloadParams
  include Api::V2::Accounts::ReportsMetricParams

  before_action :check_authorization

  OUTGOING_MESSAGES_ALLOWED_GROUP_BY = %w[agent team inbox label].freeze

  def index
    builder = V2::Reports::Conversations::ReportBuilder.new(Current.account, report_params)
    render json: builder.timeseries
  end

  def all_conversation_metrics_download
    filter_params = build_filter_params
    return handle_email_delivery(filter_params) if params[:send_email] == 'true'

    @report_data = V2::Reports::AllConversationMetricsBuilder.new(Current.account, filter_params).build
    respond_with_report_download('all_conversation_metrics', 'api/v2/accounts/reports/all_conversation_metrics')
  end

  def summary
    render json: build_summary(:summary)
  end

  def bot_summary
    render json: build_summary(:bot_summary)
  end

  def agent_activity
    return render_missing_params_error unless valid_agent_activity_params?

    build_agent_activity_data
    respond_with_report_download('agent_activity_report', 'api/v2/accounts/reports/agent_activity')
  end

  def bot_summary_download
    @report_data = generate_bots_report
    @date_range = format_date_range
    respond_with_report_download('bot_summary', 'api/v2/accounts/reports/bot_summary')
  end

  def overview_summary
    assign_overview_summary
    respond_with_report_download('overview_summary', 'api/v2/accounts/reports/overview_summary')
  end

  def agents
    @report_data = generate_agents_report
    respond_with_report_download('agents_report', 'api/v2/accounts/reports/agents')
  end

  def inboxes
    @report_data = generate_inboxes_report
    respond_with_report_download('inboxes_report', 'api/v2/accounts/reports/inboxes')
  end

  def labels
    @report_data = generate_labels_report
    respond_with_report_download('labels_report', 'api/v2/accounts/reports/labels')
  end

  def teams
    @report_data = generate_teams_report
    respond_with_report_download('teams_report', 'api/v2/accounts/reports/teams')
  end

  def conversations_summary
    @report_data = generate_conversations_report
    respond_with_report_download('conversations_summary_report', 'api/v2/accounts/reports/conversations_summary')
  end

  def conversation_traffic
    @report_data = generate_conversations_heatmap_report
    timezone_offset = (params[:timezone_offset] || 0).to_f
    @timezone = ActiveSupport::TimeZone[timezone_offset]
    respond_with_report_download('conversation_traffic_reports', 'api/v2/accounts/reports/conversation_traffic')
  end

  def drilldown
    return head :unauthorized unless Current.account_user.administrator?
    return head :unprocessable_entity unless valid_drilldown_params?

    render json: V2::Reports::DrilldownBuilder.new(Current.account, drilldown_params).build
  end

  def conversations
    return head :unprocessable_entity if params[:type].blank?

    render json: conversation_metrics
  end

  def bot_metrics
    render json: V2::Reports::BotMetricsBuilder.new(Current.account, bot_metrics_params).metrics
  end

  def inbox_label_matrix
    builder = V2::Reports::InboxLabelMatrixBuilder.new(account: Current.account, params: inbox_label_matrix_params)
    render json: builder.build
  end

  def first_response_time_distribution
    builder = V2::Reports::FirstResponseTimeDistributionBuilder.new(
      account: Current.account,
      params: first_response_time_distribution_params
    )
    render json: builder.build
  end

  def outgoing_messages_count
    return head :unprocessable_entity unless OUTGOING_MESSAGES_ALLOWED_GROUP_BY.include?(params[:group_by])

    render json: V2::Reports::OutgoingMessagesCountBuilder.new(Current.account, outgoing_messages_count_params).build
  end

  def queued_customers
    render json: V2::Reports::QueuedCustomersBuilder.new(Current.account, queued_customers_params).build
  end

  private

  def assign_overview_summary
    filter_params = build_filter_params.merge(overview_summary_params)
    log_overview_summary_window
    result = V2::Reports::OverviewSummaryBuilder.new(Current.account, filter_params).build
    @conversation_metrics = result[:conversation_metrics]
    @agent_status = result[:agent_status]
    @summary = result[:summary]
    @date_range = result[:date_range]
  end

  def log_overview_summary_window
    Rails.logger.info "1PARAMS: #{params[:since]}, #{params[:until]}, offset: #{params[:timezone_offset]}"
    Rails.logger.info "1UTC TIME: #{Time.at(params[:since].to_i).utc} - #{Time.at(params[:until].to_i).utc}"
  end
end
