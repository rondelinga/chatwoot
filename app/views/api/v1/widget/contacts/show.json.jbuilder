json.id @contact.id
json.merge! @contact.widget_presence_data
json.identifier @contact.identifier
json.blocked_until @contact.blocked_until&.iso8601
