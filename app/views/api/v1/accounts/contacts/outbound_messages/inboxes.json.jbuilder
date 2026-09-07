json.payload do
  json.array! @outbound_inboxes do |outbound_inbox|
    json.inbox do
      json.partial! 'api/v1/models/inbox_slim', formats: [:json], resource: outbound_inbox[:inbox]
    end
    json.source_id outbound_inbox[:source_id]
  end
end
