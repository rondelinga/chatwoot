# Hides deleted messages from chat queries and keeps resolved-conversation rules with the message.
module MessageSoftDeletion
  extend ActiveSupport::Concern
  include Events::Types

  included do
    belongs_to :deleted_by, class_name: 'User', optional: true
    belongs_to :audit_private_note, class_name: 'Message', optional: true

    validate :check_conversation_status, on: :create

    scope :not_deleted, -> { where(deleted_at: nil) }
    scope :chat, -> { where.not(message_type: :activity).where(private: false, deleted_at: nil) }
    scope :non_activity_messages, -> { where.not(message_type: :activity).where(deleted_at: nil).reorder('created_at desc') }
  end

  private

  def check_conversation_status
    return unless conversation&.resolved?
    return if conversation.inbox.allow_messages_after_resolved
    return unless incoming?

    errors.add(:base, 'Conversation is resolved. Please start a new conversation.')
  end

  def handle_incoming_waiting_since
    if conversation.waiting_since.blank?
      conversation.update(waiting_since: created_at)
      return
    end

    bot_message_exists = conversation.messages.where('created_at > ?', conversation.waiting_since).where('created_at < ?', created_at)
                                     .where(message_type: :outgoing).exists?(sender_type: ['AgentBot', 'Captain::Assistant'])

    conversation.update(waiting_since: created_at) if bot_message_exists
  end

  def handle_first_reply_events
    Rails.configuration.dispatcher.dispatch(FIRST_REPLY_CREATED, Time.zone.now, message: self, performed_by: Current.executed_by)

    if conversation.waiting_since.present? && !private && human_response? && conversation.first_reply_created_at.present?
      Rails.configuration.dispatcher.dispatch(REPLY_CREATED, Time.zone.now, waiting_since: conversation.waiting_since, message: self)
    end

    conversation.update(first_reply_created_at: created_at, waiting_since: nil)
  end

  def assigned_participant
    participant = conversation.conversation_participants.find_by(user_id: sender_id, left_at: nil)
    return if participant&.created_at.blank?

    participant
  end

  def valid_outgoing_count?(participant)
    conversation.messages.outgoing
                .where(sender_type: 'User', sender_id: sender_id)
                .where.not(private: true)
                .where('created_at >= ?', participant.created_at)
                .where("(additional_attributes->'campaign_id') is null")
                .count <= 1
  end
end
