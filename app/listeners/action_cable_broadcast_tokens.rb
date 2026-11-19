module ActionCableBroadcastTokens
  private

  def account_token(account)
    "account_#{account.id}"
  end

  def conversation_listener_tokens(account, conversation)
    members = conversation.inbox.members
    account_users_by_user_id = AccountUser.where(account_id: account.id, user_id: members.map(&:id)).index_by(&:user_id)

    allowed_members = members.select do |member|
      account_user = account_users_by_user_id[member.id]
      next true if account_user&.administrator?
      next true unless Conversations::AgentAccessService.restricted_agent?(account_user)

      Conversations::AgentAccessService.new(conversation: conversation, user: member, account: account, account_user: account_user).allowed?
    end

    user_tokens(account, allowed_members)
  end

  def previous_assignee_tokens(event)
    previous_assignee_id = event.data.dig(:changed_attributes, 'assignee_id')&.first
    return [] if previous_assignee_id.blank?

    User.where(id: previous_assignee_id).pluck(:pubsub_token)
  end

  def user_tokens(account, agents)
    (agents.pluck(:pubsub_token) + account.administrators.pluck(:pubsub_token)).uniq
  end

  def administrator_tokens(account)
    account.administrators.pluck(:pubsub_token)
  end

  def broadcast_message_event(message, event_name, **extra)
    conversation = message.conversation
    widget_tokens, client_tokens = split_contact_tokens(message_contact_inboxes(conversation, message))
    data = message.push_event_data.merge(extra)

    broadcast(
      conversation.account,
      conversation_listener_tokens(conversation.account, conversation) + client_tokens,
      event_name,
      data,
      widget: { tokens: widget_tokens, data: message.widget_push_event_data(data) }
    )
  end

  def broadcast_conversation_event(conversation, event_name)
    widget_tokens, client_tokens = split_contact_tokens(session_contact_inboxes(conversation.contact_inbox))
    # The web widget has no handler for conversation.updated, and the full payload includes contact details.
    widget_tokens = [] if event_name == 'conversation.updated'

    broadcast(
      conversation.account,
      conversation_listener_tokens(conversation.account, conversation) + client_tokens,
      event_name,
      conversation.push_event_data,
      widget: { tokens: widget_tokens, data: conversation.widget_push_event_data }
    )
  end

  def broadcast_typing_event(event, event_name)
    conversation = event.data[:conversation]
    user = event.data[:user]
    widget_tokens, client_tokens = split_contact_tokens(typing_contact_inboxes(conversation, user))
    data = { conversation: conversation.push_event_data, user: user.push_event_data, is_private: event.data[:is_private] || false }
    tokens = conversation_listener_tokens(conversation.account, conversation)
    tokens -= [user.pubsub_token] if user.respond_to?(:pubsub_token)

    broadcast(
      conversation.account,
      tokens + client_tokens,
      event_name,
      data,
      widget: { tokens: widget_tokens, data: data.merge(conversation: conversation.widget_push_event_data) }
    )
  end

  # Web widget sessions get the reduced widget payload. Client API sessions get the same payload as agents.
  def split_contact_tokens(contact_inboxes)
    widget_inboxes, client_inboxes = contact_inboxes.partition { |contact_inbox| contact_inbox.inbox.web_widget? }
    [widget_inboxes.filter_map(&:pubsub_token), client_inboxes.filter_map(&:pubsub_token)]
  end

  def typing_contact_inboxes(conversation, user)
    user.is_a?(Contact) ? [] : [conversation.contact_inbox]
  end

  def message_contact_inboxes(conversation, message)
    return [] if message.private? || message.activity? || conversation.contact_inbox.nil?

    session_contact_inboxes(conversation.contact_inbox)
  end

  # A verified session also reaches the contact's other verified sessions, except inboxes that no longer exist.
  def session_contact_inboxes(contact_inbox)
    return [] if contact_inbox.nil?
    return [contact_inbox] unless contact_inbox.hmac_verified?

    contact_inbox.contact.contact_inboxes.where(hmac_verified: true).where.associated(:inbox).includes(:inbox).to_a
  end

  # widget: { tokens:, data: } sends web widget sessions their payload in the same job, without the agent payload.
  def broadcast(account, tokens, event_name, data, widget: {})
    widget_tokens = widget[:tokens].to_a
    return if tokens.blank? && widget_tokens.blank?

    widget_options = {}
    widget_options = { widget_members: widget_tokens.uniq, widget_data: broadcast_payload(account, widget[:data]) } if widget_tokens.present?
    ::ActionCableBroadcastJob.perform_later(tokens.uniq, event_name, broadcast_payload(account, data), **widget_options)
  end

  def broadcast_payload(account, data)
    payload = data.merge(account_id: account.id)
    payload[:performer] = Current.user&.push_event_data if Current.user.present?
    payload
  end
end
