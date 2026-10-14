# Fork-only: XLSX format for the Enterprise SLA download (prepended in config/initializers/report_extensions.rb).
module ReportExtensions::AppliedSlasDownloadExtension
  extend ActiveSupport::Concern
  include ReportExtensions::ReportDownload

  def download
    return super unless request.format.xlsx?

    @missed_applied_slas = missed_applied_slas
    render_report_download('breached_conversation', 'api/v1/accounts/applied_slas/download')
  end
end
