require 'rails_helper'

RSpec.describe '/api/v1/widget/conversations/request_csat', type: :request do
  let(:account) { create(:account) }
  let(:web_widget) { create(:channel_widget, account: account) }
  let(:inbox) { web_widget.inbox }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }
  let(:payload) { { source_id: contact_inbox.source_id, inbox_id: inbox.id } }
  let(:token) { Widget::TokenService.new(payload: payload).generate_token }
  let(:conversation) { create(:conversation, contact: contact, account: account, inbox: inbox, contact_inbox: contact_inbox) }

  def request_csat
    post '/api/v1/widget/conversations/request_csat',
         headers: { 'X-Auth-Token' => token },
         params: { website_token: web_widget.website_token },
         as: :json
  end

  before { inbox.update!(csat_survey_enabled: true, csat_config: { 'display_type' => 'like_dislike' }) }

  it 'returns not found when the contact has no conversation' do
    request_csat

    expect(response).to have_http_status(:not_found)
  end

  context 'with a conversation' do
    before { conversation }

    it 'creates a like/dislike csat survey message' do
      expect { request_csat }.to change { conversation.messages.where(content_type: :input_csat).count }.by(1)

      expect(response).to have_http_status(:ok)
      survey = conversation.messages.where(content_type: :input_csat).last
      expect(survey.content_attributes['display_type']).to eq('like_dislike')
      expect(survey.content_attributes['allow_update']).to be_nil
    end

    it 'carries the previous response so the contact can change the rating' do
      previous_survey = create(:message, conversation: conversation, account: account, inbox: inbox, content_type: :input_csat)
      create(:csat_survey_response, conversation: conversation, message: previous_survey, account: account, contact: contact,
                                    rating: 1, feedback_message: 'slow')

      request_csat

      survey = conversation.messages.where(content_type: :input_csat).last
      expect(survey.id).not_to eq(previous_survey.id)
      expect(survey.content_attributes['allow_update']).to be(true)
      expect(survey.content_attributes['submitted_values']['csat_survey_response'])
        .to eq('rating' => 1, 'feedback_message' => 'slow')
    end

    it 'returns unprocessable entity when the display type is not like_dislike' do
      inbox.update!(csat_config: { 'display_type' => 'emoji' })

      expect { request_csat }.not_to(change { conversation.messages.count })
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns unprocessable entity when csat is disabled' do
      inbox.update!(csat_survey_enabled: false)

      request_csat

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns forbidden when the contact is blocked' do
      contact.update!(blocked: true)

      expect { request_csat }.not_to(change { conversation.messages.count })
      expect(response).to have_http_status(:forbidden)
    end
  end
end
