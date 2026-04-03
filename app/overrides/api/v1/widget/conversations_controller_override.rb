module Api::V1::Widget::ConversationsControllerOverride
  def process_update_contact
    @contact = ContactIdentifyAction.new(
      contact: @contact,
      params: { identifier: @contact.identifier,
                email: contact_email, phone_number: contact_phone_number, name: contact_name },
      retain_original_contact_name: true,
      discard_invalid_attrs: true,
      inbox_id: @web_widget.inbox.id
    ).perform

    @contact_inbox = @contact.contact_inboxes.find_by!(source_id: @contact_inbox.source_id)
  end

  def transcript
    if conversation.present? && conversation.contact.present? && conversation.contact.email.present?
      ConversationReplyMailer.with(account: conversation.account).conversation_transcript(
        conversation,
        conversation.contact.email
      )&.deliver_later
    end
    head :ok
  end
end

Rails.application.config.after_initialize do
  Api::V1::Widget::ConversationsController.prepend(Api::V1::Widget::ConversationsControllerOverride)
end
