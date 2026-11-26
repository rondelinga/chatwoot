class Messages::EditContentService
  WINDOW = 15.minutes

  class Error < StandardError; end

  pattr_initialize [:message!, :content!]

  def perform
    validate!
    return message if content == message.content

    sync_channel!
    message.update!(
      content: content,
      content_attributes: message.content_attributes.merge('edited' => true)
    )
    message
  end

  private

  def validate!
    validate_message_state!
    validate_content!
    validate_window!
  end

  def validate_message_state!
    raise Error, I18n.t('conversations.messages.edit.not_outgoing') unless message.outgoing?
    raise Error, I18n.t('conversations.messages.edit.private') if message.private?
    raise Error, I18n.t('conversations.messages.edit.deleted') if message.deleted_at.present?
  end

  def validate_content!
    raise Error, I18n.t('conversations.messages.edit.blank') if content.blank?
    raise Error, I18n.t('conversations.messages.edit.unsupported_type') unless message.text?
  end

  def validate_window!
    return if message.created_at >= WINDOW.ago

    raise Error, I18n.t('conversations.messages.edit.window', minutes: WINDOW.in_minutes.to_i)
  end

  # Widget and API updates reach the contact through the existing message.updated
  # event. Telegram can replace the text in the same message. Other channels have
  # no API to change a message the contact already received.
  def sync_channel!
    inbox = message.inbox
    return if inbox.web_widget? || inbox.api?
    return if message.source_id.blank? && message.failed?
    return sync_telegram! if inbox.telegram?

    raise Error, I18n.t('conversations.messages.edit.channel_unsupported')
  end

  def sync_telegram!
    raise Error, I18n.t('conversations.messages.edit.channel_unsupported') if message.source_id.blank?

    Telegram::EditMessageService.new(message: message, content: content).perform
  rescue Telegram::EditMessageService::Error => e
    raise Error, e.message
  end
end
