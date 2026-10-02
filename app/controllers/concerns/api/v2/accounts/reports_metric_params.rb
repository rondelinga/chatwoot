module Api::V2::Accounts::ReportsMetricParams
  extend ActiveSupport::Concern

  private

  def overview_summary_params
    { type: :account, since: params[:since], until: params[:until], timezone_offset: params[:timezone_offset],
      business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours]) }
  end

  def common_params
    { type: params[:type].to_sym, id: params[:id], group_by: params[:group_by],
      business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours]) }
  end

  def filtered_ids(key)
    params[key]&.reject(&:blank?)
  end

  def current_summary_params
    common_params.merge(since: range[:current][:since], until: range[:current][:until], timezone_offset: params[:timezone_offset],
                        inbox_ids: filtered_ids(:inbox_ids), user_ids: filtered_ids(:user_ids))
  end

  def previous_summary_params
    common_params.merge(since: range[:previous][:since], until: range[:previous][:until], timezone_offset: params[:timezone_offset],
                        inbox_ids: filtered_ids(:inbox_ids), user_ids: filtered_ids(:user_ids))
  end

  def report_params
    common_params.merge(metric: params[:metric], since: params[:since], until: params[:until], timezone_offset: params[:timezone_offset],
                        inbox_ids: filtered_ids(:inbox_ids), user_ids: filtered_ids(:user_ids))
  end

  def drilldown_params
    params.permit(:metric, :id, :since, :until, :group_by, :timezone_offset, :bucket_timestamp, :page, :per_page)
          .to_h.symbolize_keys
          .merge(type: (params[:type].presence || 'account').to_sym,
                 business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours]))
  end

  def valid_drilldown_params?
    %i[metric bucket_timestamp since until].all? { |param| params[param].present? } &&
      Reports::ReportMetricRegistry.supported?(params[:metric]) &&
      V2::Reports::DrilldownBuilder.supported_dimension_type?(params[:type]) && Reports::DrilldownTimestampValidator.valid?(params)
  end

  def conversation_params
    { type: params[:type].to_sym, user_id: params[:user_id], page: params[:page].presence || 1 }
  end

  def range
    { current: { since: params[:since], until: params[:until] },
      previous: { since: (params[:since].to_i - (params[:until].to_i - params[:since].to_i)).to_s, until: params[:since] } }
  end

  def build_summary(method)
    builder = V2::Reports::Conversations::MetricBuilder
    current_summary = builder.new(Current.account, current_summary_params).send(method)
    previous_summary = builder.new(Current.account, previous_summary_params).send(method)
    current_summary.merge(previous: previous_summary)
  end

  def conversation_metrics
    V2::ReportBuilder.new(Current.account, conversation_params).conversation_metrics
  end

  def inbox_label_matrix_params
    { since: params[:since], until: params[:until], inbox_ids: params[:inbox_ids], label_ids: params[:label_ids] }
  end

  def first_response_time_distribution_params
    { since: params[:since], until: params[:until] }
  end

  def outgoing_messages_count_params
    { group_by: params[:group_by], since: params[:since], until: params[:until] }
  end

  def queued_customers_params
    { since: params[:since], until: params[:until], team_ids: filtered_ids(:team_ids), inbox_ids: filtered_ids(:inbox_ids) }.compact
  end
end
