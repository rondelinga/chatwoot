json.id @conversation.display_id
json.inbox_id @conversation.inbox_id
json.contact_last_seen_at @conversation.contact_last_seen_at.to_i
json.status @conversation.status
json.messages do
  widget_messages = MessageFinder.new(@conversation, filter_internal_messages: true).perform
  json.array! widget_messages do |message|
    json.partial! 'api/v1/models/widget_message', resource: message
  end
end
json.custom_attributes @conversation.custom_attributes
json.contact @conversation.contact
