class Api::V1::Accounts::CsatSurveyResponsesController < Api::V1::Accounts::BaseController
  include Sift
  include DateRangeHelper
  include CsatAgentScopeConcern

  RESULTS_PER_PAGE = 25

  before_action :check_authorization
  before_action :set_csat_survey_responses, only: [:index, :metrics, :download]
  before_action :set_current_page, only: [:index]
  before_action :set_current_page_surveys, only: [:index]
  before_action :set_total_sent_messages_count, only: [:metrics]

  sort_on :created_at, type: :datetime

  def index; end

  def metrics
    @total_count = @csat_survey_responses.count
    @ratings_count = @csat_survey_responses.group(:rating).count
    @total_count_before_exclusion = if excluded_label_titles.present?
                                      @csat_responses_before_label_exclusion.count
                                    else
                                      @total_count
                                    end
  end

  def download
    respond_to do |format|
      format.csv do
        response.headers['Content-Type'] = 'text/csv'
        response.headers['Content-Disposition'] = 'attachment; filename=csat_report.csv'
        render layout: false, template: 'api/v1/accounts/csat_survey_responses/download', formats: [:csv]
      end
      format.xlsx do
        response.headers['Content-Type'] = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        response.headers['Content-Disposition'] = 'attachment; filename=csat_report.xlsx'
        render layout: false, template: 'api/v1/accounts/csat_survey_responses/download', formats: [:xlsx]
      end
      format.any do
        response.headers['Content-Type'] = 'text/csv'
        response.headers['Content-Disposition'] = 'attachment; filename=csat_report.csv'
        render layout: false, template: 'api/v1/accounts/csat_survey_responses/download', formats: [:csv]
      end
    end
  end

  private

  def set_total_sent_messages_count
    @csat_messages = Current.account.messages.input_csat
    @csat_messages = @csat_messages.joins(:conversation).where(conversations: { created_at: range }) if range.present?
    @csat_messages = apply_agent_csat_messages_scope(@csat_messages)
    if excluded_label_titles.present?
      @csat_messages = @csat_messages.where.not(conversation_id: excluded_conversation_ids)
    end
    @total_sent_messages_count = @csat_messages.count
  end

  def set_csat_survey_responses
    base_query = Current.account.csat_survey_responses
                        .includes([:conversation, :assigned_agent, :contact])

    base_query = apply_agent_csat_scope(base_query)

    @csat_survey_responses = filtrate(base_query)
                             .filter_by_conversation_created_at(range)
                             .filter_by_assigned_agent_id(permitted_user_ids)
                             .filter_by_inbox_id(Array(params[:inbox_ids]).presence)
                             .filter_by_team_id(Array(params[:team_ids]).presence)
                             .filter_by_rating(params[:rating])
    @csat_responses_before_label_exclusion = @csat_survey_responses
    return if excluded_label_titles.blank?

    @csat_survey_responses = @csat_survey_responses.excluding_conversation_labels(
      excluded_label_titles,
      Current.account.id
    )
  end

  def excluded_label_titles
    @excluded_label_titles ||= CsatSurveyResponse.normalized_label_titles(params[:excluded_labels])
  end

  def excluded_conversation_ids
    CsatSurveyResponse.conversation_ids_with_labels(excluded_label_titles, Current.account.id)
  end

  def set_current_page_surveys
    @csat_survey_responses = @csat_survey_responses
                             .page(@current_page)
                             .per(RESULTS_PER_PAGE)
  end

  def set_current_page
    @current_page = params[:page] || 1
  end
end

Api::V1::Accounts::CsatSurveyResponsesController.prepend_mod_with('Api::V1::Accounts::CsatSurveyResponsesController')
