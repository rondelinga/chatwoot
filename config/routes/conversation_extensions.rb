# Fork-only conversation routes, drawn inside the conversations scope of config/routes.rb.
post :force_transfer, to: 'force_transfers#create'
patch 'messages/:id/content', to: 'message_contents#update'
