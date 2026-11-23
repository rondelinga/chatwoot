require 'rails_helper'

RSpec.describe 'Inbox Priority Member API', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:administrator) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }

  describe 'PATCH /api/v1/accounts/{account.id}/inbox_priority_members' do
    it 'returns unauthorized for an agent' do
      create(:inbox_member, user: agent, inbox: inbox)

      patch "/api/v1/accounts/#{account.id}/inbox_priority_members",
            headers: agent.create_new_auth_token,
            params: { inbox_id: inbox.id, user_ids: [agent.id] },
            as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'sets the urgent flag for inbox collaborators' do
      other_agent = create(:user, account: account, role: :agent)
      member = create(:inbox_member, user: agent, inbox: inbox)
      outsider = create(:inbox_member, inbox: inbox)

      patch "/api/v1/accounts/#{account.id}/inbox_priority_members",
            headers: administrator.create_new_auth_token,
            params: { inbox_id: inbox.id, user_ids: [agent.id, other_agent.id] },
            as: :json

      expect(response).to have_http_status(:success)
      expect(member.reload.urgent).to be(true)
      expect(outsider.reload.urgent).to be(false)
    end

    it 'clears the urgent flag when a collaborator is unchecked' do
      member = create(:inbox_member, user: agent, inbox: inbox, urgent: true)

      patch "/api/v1/accounts/#{account.id}/inbox_priority_members",
            headers: administrator.create_new_auth_token,
            params: { inbox_id: inbox.id, user_ids: [] },
            as: :json

      expect(response).to have_http_status(:success)
      expect(member.reload.urgent).to be(false)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/inbox_teams' do
    it 'returns the urgent flag with inbox collaborators' do
      create(:inbox_member, user: agent, inbox: inbox, urgent: true)

      get "/api/v1/accounts/#{account.id}/inbox_teams",
          headers: administrator.create_new_auth_token,
          params: { inbox_id: inbox.id },
          as: :json

      collaborator = response.parsed_body.dig('payload', 'agents').find { |row| row['id'] == agent.id }
      expect(response).to have_http_status(:success)
      expect(collaborator['urgent']).to be(true)
    end
  end
end
