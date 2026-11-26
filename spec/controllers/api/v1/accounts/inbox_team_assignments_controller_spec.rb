require 'rails_helper'

RSpec.describe 'Inbox team assignments API', type: :request do
  let(:account) { create(:account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }

  describe 'POST /api/v1/accounts/{account.id}/inbox_team_assignments' do
    let(:params) do
      {
        sets: [
          {
            mode: 'add',
            inbox_ids: [inbox.id],
            team_configs: [{ team_id: team.id, is_default: true }]
          }
        ]
      }
    end

    it 'assigns the teams for an administrator' do
      post "/api/v1/accounts/#{account.id}/inbox_team_assignments",
           headers: administrator.create_new_auth_token,
           params: params,
           as: :json

      expect(response).to have_http_status(:success)
      expect(inbox.inbox_teams.find_by!(team_id: team.id).is_default).to be(true)
    end

    it 'returns unauthorized for an agent' do
      post "/api/v1/accounts/#{account.id}/inbox_team_assignments",
           headers: agent.create_new_auth_token,
           params: params,
           as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
