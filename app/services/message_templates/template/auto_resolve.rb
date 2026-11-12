class MessageTemplates::Template::AutoResolve
  AGENT_SILENCE_MESSAGE = 'Оператор не выходит на связь'.freeze
  CLIENT_SILENCE_MESSAGE = 'Клиент не выходит на связь'.freeze

  pattr_initialize [:conversation!]

  def perform
    return unless conversation.inbox.resolution_notification_enabled?

    if account.auto_resolve_split_reasons
      create_split_reason_message
      return
    end

    return if account.auto_resolve_message.blank?

    if within_messaging_window?
      conversation.messages.create!(auto_resolve_message_params)
    else
      create_auto_resolve_not_sent_activity_message
    end
  end

  private

  delegate :contact, :account, to: :conversation
  delegate :inbox, to: :message

  def within_messaging_window?
    conversation.can_reply?
  end

  def create_auto_resolve_not_sent_activity_message
    content = I18n.t('conversations.activity.auto_resolve.not_sent_due_to_messaging_window')
    activity_message_params = {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      message_type: :activity,
      content: content
    }
    ::Conversations::ActivityMessageJob.perform_later(conversation, activity_message_params) if content
  end

  def auto_resolve_message_params
    {
      account_id: @conversation.account_id,
      inbox_id: @conversation.inbox_id,
      message_type: :template,
      content: account.auto_resolve_message
    }
  end

  def create_split_reason_message
    conversation.messages.create!(
      message_type: :outgoing,
      content: split_reason_text,
      private: false,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id
    )
  end

  def split_reason_text
    if conversation.waiting_since.present?
      account.auto_resolve_message_agent.presence || AGENT_SILENCE_MESSAGE
    else
      account.auto_resolve_message_client.presence || CLIENT_SILENCE_MESSAGE
    end
  end
end
