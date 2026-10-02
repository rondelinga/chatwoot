module Api::V2::Accounts::ReportsHelper
  include Api::V2::Accounts::ReportsMetricsHelper

  def generate_agents_report
    reports = V2::Reports::AgentSummaryBuilder.new(account: Current.account, params: build_params_with_filters).build

    Current.account.users.filter_map do |agent|
      report = reports.find { |r| r[:id] == agent.id }
      next unless report

      [agent.name] + generate_readable_report_metrics(report)
    end
  end

  def generate_inboxes_report
    reports = V2::Reports::InboxSummaryBuilder.new(account: Current.account,  params: build_params_with_filters).build

    Current.account.inboxes.filter_map do |inbox|
      report = reports.find { |r| r[:id] == inbox.id }
      next unless report

      [inbox.name, inbox.channel&.name] + generate_readable_report_metrics(report)
    end
  end

  def generate_teams_report
    reports = V2::Reports::TeamSummaryBuilder.new(account: Current.account, params: build_params_with_filters).build

    Current.account.teams.filter_map do |team|
      report = reports.find { |r| r[:id] == team.id }
      next unless report

      [team.name] + generate_readable_report_metrics(report)
    end
  end

  def generate_labels_report
    reports = V2::Reports::LabelSummaryBuilder.new(account: Current.account, params: build_params_with_filters).build

    reports.map do |report|
      [report[:name]] + generate_readable_report_metrics(report)
    end
  end

  def generate_bots_report
    V2::Reports::BotSummaryReportBuilder.new(account: Current.account, params: build_params_for_bots).build
  end

  def generate_conversations_report
    builder = V2::Reports::Conversations::MetricBuilder.new(
      Current.account,
      build_params(type: :account).merge(
        user_ids: rejected_blank_array(:user_ids),
        inbox_ids: rejected_blank_array(:inbox_ids)
      )
    )
    summary = builder.summary

    [generate_conversation_report_metrics(summary)]
  end

  private

  def build_params_with_filters
    base_filter_params.merge(optional_filter_params).merge(time_range_params).compact
  end

  def base_filter_params
    { since: params[:since],  until: params[:until],  business_hours: cast_boolean(params[:business_hours]) }
  end

  def optional_filter_params
    { user_ids: rejected_blank_array(:user_ids), inbox_ids: rejected_blank_array(:inbox_ids), team_ids: rejected_blank_array(:team_ids),
      label_ids: rejected_blank_array(:label_ids) }
  end

  def time_range_params
    { time_since: params[:time_since], time_until: params[:time_until] }
  end

  def rejected_blank_array(key)
    params[key]&.reject(&:blank?)
  end

  def cast_boolean(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def build_params_for_bots
    { since: params[:since], until: params[:until], inbox_ids: rejected_blank_array(:inbox_ids) }.compact
  end

  def build_params(base_params)
    base_params.merge(
      { since: params[:since], until: params[:until], business_hours: cast_boolean(params[:business_hours]) }
    )
  end

  def report_builder(report_params)
    V2::ReportBuilder.new(Current.account, build_params(report_params))
  end
end
