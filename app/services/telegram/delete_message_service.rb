class Telegram::DeleteMessageService
  pattr_initialize [:message!]

  class Error < StandardError; end

  def perform
    return unless deletable?

    response = message.inbox.channel.delete_message(message)
    return if response.success?
    return if already_deleted?(response)

    raise Error, error_description(response)
  end

  private

  def deletable?
    message.inbox.telegram? && !message.private? && message.source_id.present?
  end

  def already_deleted?(response)
    error_description(response).match?(/message to delete not found/i)
  end

  def error_description(response)
    parsed = response.parsed_response
    return parsed['description'] if parsed.is_a?(Hash) && parsed['description'].present?

    'Telegram could not delete the message'
  end
end
