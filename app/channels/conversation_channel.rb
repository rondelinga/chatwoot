class ConversationChannel < ApplicationCable::Channel
  def subscribed
    conversation = current_account.conversations.find_by!(display_id: params[:id])
    unless conversation_accessible?(conversation)
      reject
      return
    end

    stream_for conversation
    # Account-wide stream so a supervisor watching one chat still receives
    # typing text from the agent's other chats. Agents and contacts never join it.
    stream_from supervision_stream if administrator?
  end

  # Relays the agent's draft to administrators only. Nothing is persisted and
  # the conversation stream (clients, other agents) is not used.
  def supervisor_typing(data)
    conversation = current_account.conversations.find_by!(display_id: params[:id])
    return unless conversation_accessible?(conversation)

    text = data.is_a?(Hash) ? data['text'].to_s[0, 5000] : ''
    ActionCable.server.broadcast(
      supervision_stream,
      {
        event: 'supervisor_typing_update',
        data: {
          account_id: current_account.id,
          conversation_id: conversation.display_id,
          user: current_user.push_event_data,
          text: text
        }
      }
    )
  end

  private

  def conversation_accessible?(conversation)
    return true unless restricted_agent?

    Conversations::AgentAccessService.new(
      conversation: conversation,
      user: current_user,
      account: current_account,
      account_user: account_user
    ).allowed?
  end

  def restricted_agent?
    Conversations::AgentAccessService.restricted_agent?(account_user)
  end

  def account_user
    @account_user ||= AccountUser.find_by(account_id: current_account.id, user_id: current_user.id)
  end

  def administrator?
    account_user&.administrator?
  end

  def supervision_stream
    "supervision_#{current_account.id}"
  end

  def current_user
    @current_user ||= User.find_by!(id: params[:user_id], pubsub_token: params[:pubsub_token])
  end

  def current_account
    @current_account ||= current_user.accounts.find(params[:account_id])
  end
end
