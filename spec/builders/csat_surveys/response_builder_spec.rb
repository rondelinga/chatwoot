require 'rails_helper'

describe CsatSurveys::ResponseBuilder do
  let(:message) do
    create(
      :message, content_type: :input_csat,
                content_attributes: { 'submitted_values': { 'csat_survey_response': { 'rating': 5, 'feedback_message': 'hello' } } }
    )
  end

  describe '#perform' do
    it 'creates a new csat survey response' do
      csat_survey_response = described_class.new(
        message: message
      ).perform

      expect(csat_survey_response.valid?).to be(true)
    end

    it 'updates the value of csat survey response if response already exists' do
      existing_survey_response = create(
        :csat_survey_response,
        message: message,
        conversation: message.conversation,
        account: message.account,
        contact: message.conversation.contact
      )
      csat_survey_response = described_class.new(
        message: message
      ).perform

      expect(csat_survey_response.id).to eq(existing_survey_response.id)
      expect(csat_survey_response.rating).to eq(5)
    end

    it 'reuses the conversation response when a newer survey message is rated' do
      existing_survey_response = create(
        :csat_survey_response,
        message: create(:message, conversation: message.conversation, account: message.account, content_type: :input_csat),
        conversation: message.conversation,
        account: message.account,
        contact: message.conversation.contact
      )

      csat_survey_response = described_class.new(message: message).perform

      expect(csat_survey_response.id).to eq(existing_survey_response.id)
      expect(csat_survey_response.message_id).to eq(message.id)
    end

    context 'when the survey is like/dislike' do
      let(:message) do
        create(
          :message, content_type: :input_csat,
                    content_attributes: { 'display_type': 'like_dislike',
                                          'submitted_values': { 'csat_survey_response': { 'rating': 1, 'feedback_message': '' } } }
        )
      end

      it 'creates an activity message with the rating' do
        expect { described_class.new(message: message).perform }
          .to have_enqueued_job(Conversations::ActivityMessageJob)
          .with(message.conversation, hash_including(message_type: :activity, content: I18n.t('conversations.activity.csat.rated', rating: 'bad')))
      end
    end

    it 'does not create an activity message for other display types' do
      expect { described_class.new(message: message).perform }.not_to have_enqueued_job(Conversations::ActivityMessageJob)
    end
  end
end
