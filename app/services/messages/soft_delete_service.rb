class Messages::SoftDeleteService
  def initialize(message:, deleted_by:)
    @message = message
    @deleted_by = deleted_by
  end

  def perform
    ActiveRecord::Base.transaction do
      audit_note = create_audit_note
      message.attachments.update_all(message_id: audit_note.id) # rubocop:disable Rails/SkipsModelValidations

      message.update!(
        content: nil,
        content_type: :text,
        content_attributes: message.content_attributes.slice('forwarded_message_id').merge(deleted: true),
        deleted_at: Time.current,
        deleted_by: deleted_by,
        original_content: original_content,
        audit_private_note_id: audit_note.id
      )
    end

    message
  end

  private

  attr_reader :message, :deleted_by

  def original_content
    @original_content ||= message.content
  end

  def create_audit_note
    message.conversation.messages.create!(
      account_id: message.account_id,
      inbox_id: message.inbox_id,
      message_type: :activity,
      private: true,
      sender: message.sender,
      content: audit_note_content,
      content_attributes: { deleted_audit_note: true }
    )
  end

  def audit_note_content
    agent_name = message.sender.try(:name) || I18n.t('conversations.messages.deleted_audit_note.unknown_sender')
    header = I18n.t('conversations.messages.deleted_audit_note.header', agent_name: agent_name)
    return header if original_content.blank?

    "#{header}\n\n#{I18n.t('conversations.messages.deleted_audit_note.body_label')}\n_\"#{original_content}\"_"
  end
end
