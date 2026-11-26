# Fork-only account routes, drawn inside the api/v1/accounts scope of config/routes.rb.
resources :inbox_team_assignments, only: [:create]
