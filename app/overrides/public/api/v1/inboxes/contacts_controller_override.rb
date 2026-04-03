module Public::Api::V1::Inboxes::ContactsControllerOverride
  def update
    contact_identify_action = ContactIdentifyAction.new(
      contact: @contact_inbox.contact,
      params: permitted_params.to_h.deep_symbolize_keys.except(:identifier),
      inbox_id: @inbox_channel.inbox.id
    )
    render json: contact_identify_action.perform
  end
end

Public::Api::V1::Inboxes::ContactsController.prepend(Public::Api::V1::Inboxes::ContactsControllerOverride)
