json.merge! @conversation.widget_push_event_data
json.messages do
  widget_messages = MessageFinder.new(@conversation, filter_internal_messages: true).perform
  json.array! widget_messages do |message|
    json.partial! 'api/v1/models/widget_message', resource: message
  end
end
json.custom_attributes @conversation.custom_attributes
