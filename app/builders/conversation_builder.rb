class ConversationBuilder
  pattr_initialize [:params!, :contact_inbox!]

  def perform
    look_up_exising_conversation || create_new_conversation
  end

  private

  def look_up_exising_conversation
    return @contact_inbox.conversations.last if @contact_inbox.inbox.lock_to_single_conversation?
    return @contact_inbox.conversations.where.not(status: :resolved).last if session_based_inbox?

    nil
  end

  # Web widget and Telegram conversations are tied to a single ongoing session with the
  # contact, so we reuse the last conversation instead of creating a new one every time,
  # unless that conversation has been resolved.
  def session_based_inbox?
    @contact_inbox.inbox.web_widget? || @contact_inbox.inbox.telegram?
  end

  def create_new_conversation
    ::Conversation.create!(conversation_params)
  end

  def conversation_params
    additional_attributes = (params[:additional_attributes]&.permit! || {}).to_h.merge(telegram_additional_attributes)
    custom_attributes = params[:custom_attributes]&.permit! || {}
    status = params[:status].present? ? { status: params[:status] } : {}

    {
      account_id: @contact_inbox.inbox.account_id,
      inbox_id: @contact_inbox.inbox_id,
      contact_id: @contact_inbox.contact_id,
      contact_inbox_id: @contact_inbox.id,
      additional_attributes: additional_attributes,
      custom_attributes: custom_attributes,
      snoozed_until: params[:snoozed_until],
      assignee_id: params[:assignee_id],
      team_id: params[:team_id],
      assignee_agent_bot_id: params[:assignee_agent_bot_id]
    }.compact.merge(status)
  end

  # Telegram requires the chat_id to be present in additional_attributes to be able to
  # send messages, so we carry it over from the contact's previous conversation or session.
  def telegram_additional_attributes
    return {} unless @contact_inbox.inbox.telegram?

    previous_attrs = @contact_inbox.conversations.order(last_activity_at: :desc).first&.additional_attributes || {}
    {
      'chat_id' => previous_attrs['chat_id'].presence || @contact_inbox.source_id,
      'business_connection_id' => previous_attrs['business_connection_id']
    }.compact
  end
end
