json.payload do
  json.array! @routing_types do |routing_type|
    json.partial! 'api/v1/accounts/routing_types/routing_type', routing_type: routing_type
  end
end
