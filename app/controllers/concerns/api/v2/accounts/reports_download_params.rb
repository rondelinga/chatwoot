module Api::V2::Accounts::ReportsDownloadParams
  extend ActiveSupport::Concern

  private

  def build_filter_params
    {
      since: params[:since],
      until: params[:until],
      user_ids: params[:user_ids],
      inbox_ids: params[:inbox_ids],
      team_ids: params[:team_ids],
      label_ids: params[:label_ids],
      time_since: params[:time_since],
      time_until: params[:time_until]
    }.compact
  end

  def handle_email_delivery(filter_params)
    recipient_email = params[:email].presence || current_user.email

    Reports::AllMetricsJob.perform_later(Current.account.id, current_user.id,
                                         filter_params.merge(format: params[:format] || 'csv', email: recipient_email))

    render json: { message: I18n.t('reports.email_delivery.queued'), status: 'queued', email: recipient_email }, status: :accepted
  end

  def valid_agent_activity_params?
    return true if params[:since].presence&.to_i && params[:until].presence&.to_i

    render json: { error: 'since and until are required' }, status: :unprocessable_entity
    false
  end

  def build_agent_activity_data
    builder = V2::Reports::AgentActivityBuilder.new(Current.account, agent_activity_params)
    @since = Time.zone.at(params[:since].to_i)
    @until = Time.zone.at(params[:until].to_i)
    @agents = builder.call
  end

  def agent_activity_params
    params.permit(:since, :until, :timezone_offset, :hide_inactive, team_ids: [], user_ids: [], inbox_ids: [])
  end

  def bot_metrics_params
    params.permit(:since, :until, inbox_ids: [])
  end

  def check_authorization
    authorize({ action: action_name, type: params[:type] }, :view?, policy_class: ReportPolicy)
  end
end
