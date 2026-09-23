json.id @message.id
json.deleted @message.deleted_at.present?
json.deleted_at @message.deleted_at
