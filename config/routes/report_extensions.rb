# Fork-only report routes, drawn inside the `api/v2/accounts` scope of config/routes.rb.
resources :summary_reports, only: [] do
  collection do
    get :agent_activity
    get :bot
  end
end

resources :reports, only: [], controller: 'extended_reports' do
  collection do
    get :agent_activity
    get :overview_summary
    get :bot_summary_download
    get :all_conversation_metrics_download
    get :queued_customers
  end
end
