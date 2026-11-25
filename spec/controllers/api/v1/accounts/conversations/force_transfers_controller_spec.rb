require 'rails_helper'

RSpec.describe 'Conversation force transfer API', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:teammate) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent, team: team) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    create(:inbox_member, inbox: inbox, user: teammate)
    create(:team_member, team: team, user: agent)
    create(:team_member, team: team, user: teammate)
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(teammate.id.to_s => 'online')
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/<id>/force_transfer' do
    it 'returns unauthorized for a guest' do
      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/force_transfer"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'assigns another member of the conversation team' do
      post "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/force_transfer",
           headers: agent.create_new_auth_token,
           as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body['agent']['id']).to eq(teammate.id)
      expect(conversation.reload.assignee).to eq(teammate)
    end
  end
end
