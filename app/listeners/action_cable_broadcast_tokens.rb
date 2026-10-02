module ActionCableBroadcastTokens
  private

  def account_token(account)
    "account_#{account.id}"
  end

  def typing_event_listener_tokens(account, conversation, user)
    current_user_token = if user.is_a?(Contact)
                           conversation.contact_inbox.pubsub_token
                         elsif user.respond_to?(:pubsub_token)
                           user.pubsub_token
                         end

    tokens = conversation_listener_tokens(account, conversation) + [conversation.contact_inbox.pubsub_token]
    current_user_token.present? ? tokens - [current_user_token] : tokens
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

  def contact_tokens(contact_inbox, message)
    return [] if message.private? || message.activity? || contact_inbox.nil?

    contact_inbox_tokens(contact_inbox)
  end

  def contact_inbox_tokens(contact_inbox)
    contact = contact_inbox.contact
    contact_inbox.hmac_verified? ? contact.contact_inboxes.where(hmac_verified: true).filter_map(&:pubsub_token) : [contact_inbox.pubsub_token]
  end

  def broadcast(account, tokens, event_name, data)
    return if tokens.blank?

    payload = data.merge(account_id: account.id)
    payload[:performer] = Current.user&.push_event_data if Current.user.present?
    ::ActionCableBroadcastJob.perform_later(tokens.uniq, event_name, payload)
  end
end
