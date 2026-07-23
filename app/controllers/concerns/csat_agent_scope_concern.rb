module CsatAgentScopeConcern
  extend ActiveSupport::Concern

  private

  def apply_agent_csat_scope(relation)
    return relation unless restricted_agent?

    relation.where(conversation_id: accessible_conversation_ids)
  end

  def apply_agent_csat_messages_scope(relation)
    return relation unless restricted_agent?

    relation.where(conversation_id: accessible_conversation_ids)
  end

  def restricted_agent?
    account_user&.agent? && account_user.custom_role_id.blank?
  end

  def account_user
    Current.account.account_users.find_by(user: Current.user)
  end

  def accessible_conversation_ids
    Conversations::PermissionFilterService.new(
      Current.account.conversations,
      Current.user,
      Current.account
    ).perform.select(:id)
  end

  def permitted_user_ids
    return params[:user_ids] unless restricted_agent?

    [Current.user.id]
  end
end
