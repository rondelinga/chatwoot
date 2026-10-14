require 'rails_helper'

describe MessageTemplates::Template::CsatSurvey do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:service) { described_class.new(conversation: conversation) }

  describe '#perform' do
    context 'when no survey rules are configured' do
      it 'creates a CSAT survey message' do
        inbox.update(csat_config: {})

        service.perform

        expect(conversation.messages.template.count).to eq(1)
        expect(conversation.messages.template.first.content_type).to eq('input_csat')
      end
    end

    context 'when csat config is provided' do
      let(:csat_config) do
        {
          'display_type' => 'star',
          'message' => 'Please rate your experience'
        }
      end

      before { inbox.update(csat_config: csat_config) }

      it 'creates a CSAT message with configured attributes' do
        service.perform

        message = conversation.messages.template.last
        expect(message.content_type).to eq('input_csat')
        expect(message.content).to eq('Please rate your experience')
        expect(message.content_attributes['display_type']).to eq('star')
      end
    end

    context 'when an existing response is passed' do
      let(:csat_survey_response) { create(:csat_survey_response, conversation: conversation, account: account, rating: 5, feedback_message: 'great') }

      it 'allows the contact to update the previous rating' do
        inbox.update(csat_config: { 'display_type' => 'like_dislike' })

        described_class.new(conversation: conversation, existing_response: csat_survey_response).perform

        message = conversation.messages.template.last
        expect(message.content_attributes['display_type']).to eq('like_dislike')
        expect(message.content_attributes['allow_update']).to be(true)
        expect(message.content_attributes['submitted_values']['csat_survey_response']).to eq('rating' => 5, 'feedback_message' => 'great')
      end
    end
  end
end
