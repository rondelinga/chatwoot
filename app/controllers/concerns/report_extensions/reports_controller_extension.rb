# Fork-only additions to the upstream Api::V2::Accounts::ReportsController (prepended in
# config/initializers/report_extensions.rb): XLSX downloads, extra CSV columns/filters
# (via ReportExtensions::ReportsHelper and overridden templates) and per-report access control.
module ReportExtensions::ReportsControllerExtension
  extend ActiveSupport::Concern
  include ReportExtensions::ReportDownload

  prepended { include ReportExtensions::ReportsHelper }

  private

  def generate_csv(filename, template)
    return super unless request.format.xlsx?

    render_report_download(filename, template)
  end

  def check_authorization
    authorize({ action: action_name, type: params[:type] }, :view?, policy_class: ReportPolicy)
  end

  def common_params
    super.merge(inbox_ids: filtered_ids(:inbox_ids), user_ids: filtered_ids(:user_ids))
  end
end
