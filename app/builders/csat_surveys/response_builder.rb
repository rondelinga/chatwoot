class CsatSurveys::ResponseBuilder
  pattr_initialize [:message]

  def perform
    raise 'Invalid Message' unless message.input_csat?

    conversation = message.conversation
    rating = message.content_attributes.dig('submitted_values', 'csat_survey_response', 'rating')
    feedback_message = message.content_attributes.dig('submitted_values', 'csat_survey_response', 'feedback_message')

    return if rating.blank?

    process_csat_response(conversation, rating, feedback_message)
  end

  private

  def process_csat_response(conversation, rating, feedback_message)
    csat_survey_response = existing_response_for_conversation(conversation) || CsatSurveyResponse.new(
      message_id: message.id, account_id: message.account_id, conversation_id: message.conversation_id,
      contact_id: conversation.contact_id, assigned_agent: conversation.assignee
    )
    csat_survey_response.message = message
    csat_survey_response.rating = rating
    csat_survey_response.feedback_message = feedback_message
    csat_survey_response.save!
    create_like_dislike_activity_message(conversation, csat_survey_response)
    csat_survey_response
  end

  def existing_response_for_conversation(conversation)
    CsatSurveyResponse.where(conversation_id: conversation.id).order(created_at: :asc).first
  end

  def create_like_dislike_activity_message(conversation, csat_survey_response)
    return unless csat_survey_response.display_type == 'like_dislike'

    ::Conversations::ActivityMessageJob.perform_later(
      conversation,
      {
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: :activity,
        content: I18n.t('conversations.activity.csat.rated', rating: csat_survey_response.report_rating)
      }
    )
  end
end
