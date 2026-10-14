require 'rails_helper'

RSpec.describe 'Report extensions API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:inbox) { create(:inbox, account: account) }
  let(:params) { { since: 30.days.ago.to_i.to_s, until: Time.current.end_of_day.to_i.to_s } }
  let(:xlsx_content_type) { 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' }

  before do
    create(:conversation, account: account, inbox: inbox, assignee: admin)
  end

  describe 'upstream report downloads' do
    it 'keeps CSV as the default format with the extra agent columns' do
      get "/api/v2/accounts/#{account.id}/reports/agents", params: params, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to start_with('text/csv')
      expect(response.headers['Content-Disposition']).to eq('attachment; filename=agents_report.csv')
      expect(response.body).to include(I18n.t('reports.agent_csv.csat_score'))
    end

    it 'returns XLSX when requested' do
      get "/api/v2/accounts/#{account.id}/reports/agents.xlsx", params: params, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to eq(xlsx_content_type)
      expect(response.headers['Content-Disposition']).to eq('attachment; filename=agents_report.xlsx')
      expect(response.body).to start_with('PK')
    end

    %w[agents inboxes teams labels].each do |report|
      it "keeps the #{report} CSV headers aligned with the row values" do
        create(:team, account: account)
        account.conversations.first.update_labels([create(:label, account: account).title])

        get "/api/v2/accounts/#{account.id}/reports/#{report}.csv", params: params, headers: admin.create_new_auth_token

        headers, *rows = CSV.parse(response.body).reject(&:empty?).drop(1)
        expect(rows).not_to be_empty
        expect(rows.map(&:size).uniq).to eq([headers.size])
      end
    end

    it 'applies the user filter to the agents CSV' do
      other_agent = create(:user, account: account, role: :agent)

      get "/api/v2/accounts/#{account.id}/reports/agents.csv",
          params: params.merge(user_ids: [admin.id]),
          headers: admin.create_new_auth_token

      names = CSV.parse(response.body).drop(2).map(&:first)
      expect(names).to include(admin.name)
      expect(names).not_to include(other_agent.name)
    end
  end

  describe 'GET /api/v2/accounts/:account_id/reports/overview_summary' do
    it 'returns the overview CSV' do
      get "/api/v2/accounts/#{account.id}/reports/overview_summary.csv", params: params, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Disposition']).to eq('attachment; filename=overview_summary.csv')
    end

    it 'returns the overview XLSX' do
      get "/api/v2/accounts/#{account.id}/reports/overview_summary.xlsx", params: params, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to eq(xlsx_content_type)
    end
  end

  describe 'GET /api/v2/accounts/:account_id/reports/bot_summary_download' do
    it 'returns the bot summary CSV' do
      get "/api/v2/accounts/#{account.id}/reports/bot_summary_download.csv",
          params: params.merge(inbox_ids: [inbox.id]),
          headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Disposition']).to eq('attachment; filename=bot_summary.csv')
    end
  end

  describe 'GET /api/v2/accounts/:account_id/reports/agent_activity' do
    it 'requires since and until' do
      get "/api/v2/accounts/#{account.id}/reports/agent_activity", headers: admin.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns the agent activity CSV' do
      get "/api/v2/accounts/#{account.id}/reports/agent_activity", params: params, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Disposition']).to eq('attachment; filename=agent_activity_report.csv')
    end
  end

  describe 'GET /api/v2/accounts/:account_id/reports/all_conversation_metrics_download' do
    it 'returns the conversation metrics CSV' do
      get "/api/v2/accounts/#{account.id}/reports/all_conversation_metrics_download.csv", params: params, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Disposition']).to eq('attachment; filename=all_conversation_metrics.csv')
    end

    it 'queues the report email when send_email is set' do
      expect do
        get "/api/v2/accounts/#{account.id}/reports/all_conversation_metrics_download.csv",
            params: params.merge(send_email: 'true'),
            headers: admin.create_new_auth_token
      end.to have_enqueued_job(Reports::AllMetricsJob)

      expect(response).to have_http_status(:accepted)
      expect(response.parsed_body['email']).to eq(admin.email)
    end
  end

  describe 'GET /api/v2/accounts/:account_id/reports/queued_customers' do
    it 'returns queued customer metrics' do
      get "/api/v2/accounts/#{account.id}/reports/queued_customers", params: params, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.keys).to match_array(%w[summary waiting_time daily heatmap])
    end
  end

  describe 'GET /api/v1/accounts/:account_id/csat_survey_responses/download.xlsx' do
    it 'returns the CSAT report as XLSX' do
      create(:csat_survey_response, account: account)

      get "/api/v1/accounts/#{account.id}/csat_survey_responses/download.xlsx", params: params, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to eq(xlsx_content_type)
      expect(response.headers['Content-Disposition']).to eq('attachment; filename=csat_report.xlsx')
    end
  end

  describe 'GET /api/v1/accounts/:account_id/applied_slas/download.xlsx' do
    it 'returns breached conversations as XLSX' do
      account.enable_features!('sla')
      conversation = create(:conversation, account: account, inbox: inbox)
      create(:applied_sla, sla_policy: create(:sla_policy, account: account), conversation: conversation, sla_status: 'missed')

      get "/api/v1/accounts/#{account.id}/applied_slas/download.xlsx", params: params, headers: admin.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Type']).to eq(xlsx_content_type)
      expect(response.headers['Content-Disposition']).to eq('attachment; filename=breached_conversation.xlsx')
    end
  end
end
