# Fork-only: XLSX format for the upstream CSAT download (prepended in config/initializers/report_extensions.rb).
module ReportExtensions::CsatDownloadExtension
  extend ActiveSupport::Concern
  include ReportExtensions::ReportDownload

  def download
    return super unless request.format.xlsx?

    render_report_download('csat_report', 'api/v1/accounts/csat_survey_responses/download')
  end
end
