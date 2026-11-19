# Fork-only overrides of Api::V2::Accounts::ReportsHelper: applies the report filters
# (users, inboxes, teams, labels, time of day) to the CSV/XLSX downloads, skips rows the
# filters exclude and appends the agent chat duration and CSAT score columns.
module ReportExtensions::ReportsHelper
  def generate_agents_report
    reports = V2::Reports::AgentSummaryBuilder.new(account: Current.account, params: filtered_report_params).build

    Current.account.users.filter_map do |agent|
      report = reports.find { |r| r[:id] == agent.id }
      [agent.name] + generate_readable_report_metrics(report) if report
    end
  end

  def generate_inboxes_report
    reports = V2::Reports::InboxSummaryBuilder.new(account: Current.account, params: filtered_report_params).build

    Current.account.inboxes.filter_map do |inbox|
      report = reports.find { |r| r[:id] == inbox.id }
      [inbox.name, inbox.channel&.name] + generate_readable_report_metrics(report) if report
    end
  end

  def generate_teams_report
    reports = V2::Reports::TeamSummaryBuilder.new(account: Current.account, params: filtered_report_params).build

    Current.account.teams.filter_map do |team|
      report = reports.find { |r| r[:id] == team.id }
      [team.name] + generate_readable_report_metrics(report) if report
    end
  end

  def generate_labels_report
    reports = V2::Reports::LabelSummaryBuilder.new(account: Current.account, params: filtered_report_params).build

    reports.map do |report|
      [report[:name]] + generate_readable_report_metrics(report)
    end
  end

  def generate_conversations_report
    builder = V2::Reports::Conversations::MetricBuilder.new(
      Current.account,
      build_params(type: :account).merge(user_ids: filtered_ids(:user_ids), inbox_ids: filtered_ids(:inbox_ids))
    )

    [generate_conversation_report_metrics(builder.summary)]
  end

  def generate_bots_report
    V2::Reports::BotSummaryReportBuilder.new(
      account: Current.account,
      params: { since: params[:since], until: params[:until], inbox_ids: filtered_ids(:inbox_ids) }.compact
    ).build
  end

  private

  def filtered_report_params
    {
      since: params[:since],
      until: params[:until],
      business_hours: ActiveModel::Type::Boolean.new.cast(params[:business_hours]),
      user_ids: filtered_ids(:user_ids),
      inbox_ids: filtered_ids(:inbox_ids),
      team_ids: filtered_ids(:team_ids),
      label_ids: filtered_ids(:label_ids),
      time_since: params[:time_since],
      time_until: params[:time_until]
    }.compact
  end

  def filtered_ids(key)
    params[key]&.reject(&:blank?)
  end

  def generate_readable_report_metrics(report)
    metrics = super
    # Only the agent summary tracks chat duration; inbox, team and label exports have no column for it
    metrics << Reports::TimeFormatPresenter.new(report[:agent_chat_duration]).format if report.key?(:agent_chat_duration)
    metrics << (report[:csat_satisfaction_score] ? "#{report[:csat_satisfaction_score]}%" : '--')
  end

  def format_date_range
    { since: Time.zone.at(params[:since].to_i), until: Time.zone.at(params[:until].to_i) }
  end
end
