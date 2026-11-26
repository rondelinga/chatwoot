require 'rails_helper'

RSpec.describe 'Conversation message content API', type: :request do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) do
    create(:message, message_type: :outgoing, content: 'hello', conversation: conversation, account: account)
  end

  before do
    create(:inbox_member, inbox: inbox, user: agent)
  end

  describe 'PATCH /api/v1/accounts/{account.id}/conversations/<id>/messages/<id>/content' do
    it 'updates the message text' do
      patch "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}/messages/#{message.id}/content",
            params: { content: 'updated' },
            headers: agent.create_new_auth_token,
            as: :json

      expect(response).to have_http_status(:ok)
      expect(message.reload.content).to eq('updated')
      expect(message.content_attributes['edited']).to be(true)
    end
  end
end
