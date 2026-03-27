module Overrides
  module Public
    module Api
      module V1
        module Inboxes
          module ContactsControllerOverride
            def update
              contact_identify_action = ContactIdentifyAction.new(
                contact: @contact_inbox.contact,
                params: permitted_params.to_h.deep_symbolize_keys.except(:identifier),
                inbox_id: @inbox_channel.inbox.id
              )
              render json: contact_identify_action.perform
            end
          end
        end
      end
    end
  end
end

Public::Api::V1::Inboxes::ContactsController.prepend(Overrides::Public::Api::V1::Inboxes::ContactsControllerOverride)
