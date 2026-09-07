class Contacts::OutboundMessageService
  class Error < StandardError; end

  pattr_initialize [:account!, :user!, :contact!, :inbox!, :content!]

  def perform
    validate!
    conversation = find_or_create_conversation
    message = create_message(conversation)

    { conversation: conversation, message: message }
  end

  def self.inboxes_for(contact:, user:)
    contact.contact_inboxes
           .includes(:inbox)
           .filter_map { |contact_inbox| inbox_payload(contact_inbox, user) }
           .uniq { |payload| payload[:inbox].id }
  end

  def self.inbox_payload(contact_inbox, user)
    inbox = contact_inbox.inbox
    return unless supported_inbox?(inbox)
    return unless user.assigned_inboxes.include?(inbox)

    { source_id: contact_inbox.source_id, inbox: inbox }
  end
  private_class_method :inbox_payload

  def self.supported_inbox?(inbox)
    inbox&.web_widget? || inbox&.telegram?
  end
  private_class_method :supported_inbox?

  private

  def validate!
    raise Error, I18n.t('errors.contacts.outbound_message.blank') if content.to_s.strip.blank?
    raise Error, I18n.t('errors.contacts.outbound_message.inbox_not_supported') unless outbound_inbox?
    raise Error, I18n.t('errors.contacts.outbound_message.no_session') if contact_inbox.blank?
  end

  def outbound_inbox?
    inbox.web_widget? || inbox.telegram?
  end

  def find_or_create_conversation
    reusable = reusable_conversation
    if reusable.present?
      assign_sender!(reusable)
      reusable.open! unless reusable.open?
      return reusable
    end

    create_conversation
  end

  def reusable_conversation
    conversations = contact.conversations.where(inbox_id: inbox.id)
    if inbox.telegram? && inbox.lock_to_single_conversation?
      conversations.order(last_activity_at: :desc).first
    else
      conversations.open.order(last_activity_at: :desc).first
    end
  end

  def create_conversation
    conversation = Conversation.create!(
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox,
      assignee: user,
      status: :open,
      additional_attributes: conversation_additional_attributes
    )
    conversation.open! if conversation.pending?
    conversation
  end

  def conversation_additional_attributes
    return {} unless inbox.telegram?

    previous_attrs = contact_inbox.conversations.order(last_activity_at: :desc).first&.additional_attributes || {}
    {
      'chat_id' => previous_attrs['chat_id'].presence || contact_inbox.source_id,
      'business_connection_id' => previous_attrs['business_connection_id']
    }.compact
  end

  def assign_sender!(conversation)
    return if conversation.assignee_id == user.id

    conversation.update!(assignee: user)
  end

  def create_message(conversation)
    Messages::MessageBuilder.new(user, conversation, { content: content.strip, message_type: 'outgoing' }).perform
  end

  def contact_inbox
    @contact_inbox ||= contact.contact_inboxes.where(inbox_id: inbox.id).last
  end
end
