# Fork-only report endpoints. Routed under /api/v2/accounts/:account_id/reports/* by
# config/routes/report_extensions.rb, next to the upstream Api::V2::Accounts::ReportsController.
class Api::V2::Accounts::ExtendedReportsController < Api::V1::Accounts::BaseController
  include Api::V2::Accounts::ReportsHelper
  include ReportExtensions::ReportsHelper
  include ReportExtensions::ReportDownload

  before_action :check_authorization

  def all_conversation_metrics_download
    return deliver_all_conversation_metrics_by_email if params[:send_email] == 'true'

    @report_data = V2::Reports::AllConversationMetricsBuilder.new(Current.account, download_filter_params).build
    render_report_download('all_conversation_metrics', 'api/v2/accounts/reports/all_conversation_metrics')
  end

  def agent_activity
    return render json: { error: 'since and until are required' }, status: :unprocessable_entity if params[:since].blank? || params[:until].blank?

    @since = Time.zone.at(params[:since].to_i)
    @until = Time.zone.at(params[:until].to_i)
    @agents = V2::Reports::AgentActivityBuilder.new(Current.account, agent_activity_params).call
    render_report_download('agent_activity_report', 'api/v2/accounts/reports/agent_activity')
  end

  def bot_summary_download
    @report_data = generate_bots_report
    @date_range = format_date_range
    render_report_download('bot_summary', 'api/v2/accounts/reports/bot_summary')
  end

  def overview_summary
    result = V2::Reports::OverviewSummaryBuilder.new(Current.account, download_filter_params.merge(overview_summary_params)).build
    @conversation_metrics = result[:conversation_metrics]
    @agent_status = result[:agent_status]
    @summary = result[:summary]
    @date_range = result[:date_range]
    render_report_download('overview_summary', 'api/v2/accounts/reports/overview_summary')
  end

  def queued_customers
    render json: V2::Reports::QueuedCustomersBuilder.new(Current.account, queued_customers_params).build
  end

  private

  def check_authorization
    authorize({ action: action_name, type: params[:type] }, :view?, policy_class: ReportPolicy)
  end

  def deliver_all_conversation_metrics_by_email
    recipient_email = params[:email].presence || current_user.email
    Reports::AllMetricsJob.perform_later(Current.account.id, current_user.id,
                                         download_filter_params.merge(format: params[:format] || 'csv', email: recipient_email))

    render json: { message: I18n.t('reports.email_delivery.queued'), status: 'queued', email: recipient_email }, status: :accepted
  end

  def download_filter_params
    { since: params[:since], until: params[:until], user_ids: params[:user_ids], inbox_ids: params[:inbox_ids], team_ids: params[:team_ids],
      label_ids: params[:label_ids], time_since: params[:time_since], time_until: params[:time_until] }.compact
  end

  def overview_summary_params
    { type: :account, since: params[:since], until: params[:until], timezone_offset: params[:timezone_offset],
      business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours]) }
  end

  def agent_activity_params
    params.permit(:since, :until, :timezone_offset, :hide_inactive, team_ids: [], user_ids: [], inbox_ids: [])
  end

  def queued_customers_params
    { since: params[:since], until: params[:until], team_ids: filtered_ids(:team_ids), inbox_ids: filtered_ids(:inbox_ids) }.compact
  end
end
