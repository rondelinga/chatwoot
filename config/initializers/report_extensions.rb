# Fork-only report extensions are attached here so the upstream controllers stay untouched.
Rails.application.config.to_prepare do
  Api::V2::Accounts::ReportsController.prepend(ReportExtensions::ReportsControllerExtension)
  Api::V1::Accounts::CsatSurveyResponsesController.prepend(ReportExtensions::CsatDownloadExtension)
  Api::V1::Accounts::AppliedSlasController.prepend(ReportExtensions::AppliedSlasDownloadExtension) if ChatwootApp.enterprise?
end
