class Telegram::EditMessageService
  pattr_initialize [:message!, :content!]

  class Error < StandardError; end

  def perform
    return unless message.inbox.telegram?
    return if message.private? || message.source_id.blank?

    response = request_edit
    return if response.success?

    raise Error, error_description(response)
  end

  private

  def request_edit
    channel = message.inbox.channel
    body = {
      chat_id: channel.chat_id(message),
      message_id: message.source_id
    }
    connection_id = channel.business_connection_id(message)
    body[:business_connection_id] = connection_id if connection_id.present?

    if message.attachments.exists?
      body[:caption] = content
      endpoint = 'editMessageCaption'
    else
      body[:text] = content
      endpoint = 'editMessageText'
    end

    HTTParty.post("#{channel.telegram_api_url}/#{endpoint}", body: body)
  end

  def error_description(response)
    parsed = response.parsed_response
    return parsed['description'] if parsed.is_a?(Hash) && parsed['description'].present?

    'Telegram could not edit the message'
  end
end
