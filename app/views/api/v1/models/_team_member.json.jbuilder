json.id team_member.user.id
json.account_id Current.account&.id
json.assignment_tier team_member.assignment_tier
json.availability_status team_member.user.availability_status
json.auto_offline team_member.user.auto_offline
json.confirmed team_member.user.confirmed?
json.email team_member.user.email
json.provider team_member.user.provider
json.available_name team_member.user.available_name
json.custom_attributes team_member.user.custom_attributes if team_member.user.custom_attributes.present?
json.name team_member.user.name
json.role team_member.user.role
json.thumbnail team_member.user.avatar_url
json.custom_role_id team_member.user.current_account_user&.custom_role_id if ChatwootApp.enterprise?
json.active_chat_limit team_member.user.current_account_user&.active_chat_limit
json.active_chat_limit_enabled team_member.user.current_account_user&.active_chat_limit_enabled
