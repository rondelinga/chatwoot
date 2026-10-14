# Fork-only: renders report templates as CSV or XLSX attachments.
# Templates live in app/views/report_extensions, which is prepended to the view paths
# so it can also override upstream CSV templates of the same name.
module ReportExtensions::ReportDownload
  extend ActiveSupport::Concern

  VIEW_PATH = Rails.root.join('app/views/report_extensions').to_s.freeze

  included { prepend_view_path VIEW_PATH }
  prepended { prepend_view_path VIEW_PATH }

  private

  def render_report_download(filename, template)
    format = request.format.xlsx? ? :xlsx : :csv
    response.headers['Content-Type'] = Mime[format].to_s
    response.headers['Content-Disposition'] = "attachment; filename=#{filename}.#{format}"
    render layout: false, template: template, formats: [format]
  end
end
