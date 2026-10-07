# Lets a widget contact ask for a like/dislike CSAT survey at any time ("Rate chat" button).
# The survey carries the previous response so the contact can change their rating.
class Api::V1::Widget::CsatRequestsController < Api::V1::Widget::BaseController
  def create
    return head :not_found if conversation.nil?
    return head :unprocessable_entity unless like_dislike_csat_enabled?
    return head :forbidden if conversation.contact&.blocked?

    ::MessageTemplates::Template::CsatSurvey.new(
      conversation: conversation,
      existing_response: CsatSurveyResponse.find_by(conversation_id: conversation.id)
    ).perform
    head :ok
  end

  private

  def like_dislike_csat_enabled?
    conversation.inbox.csat_survey_enabled? && conversation.inbox.csat_config['display_type'] == 'like_dislike'
  end

  def permitted_params
    params.permit(:website_token)
  end
end
