class Conversations::AgentAccessService
  DEFAULT_HISTORY_DAYS = 30

  pattr_initialize [:conversation!, :user!, :account!, :account_user]

  class << self
    def apply_scope(conversations, user, account)
      account_user = find_account_user(user, account)
      return conversations unless restricted_agent?(account_user)

      scoped = apply_assignment_scope(conversations, user)
      apply_history_limit(scoped, account)
    end

    def restricted_agent?(account_user)
      account_user&.agent? && account_user.custom_role_id.blank?
    end

    def find_account_user(user, account)
      AccountUser.find_by(account_id: account.id, user_id: user.id)
    end

    def history_days(account)
      value = account.agent_history_days
      return DEFAULT_HISTORY_DAYS if value.nil?

      value.to_i
    end

    private

    def apply_assignment_scope(conversations, user)
      conversations.where('conversations.assignee_id = ? OR conversations.assignee_id IS NULL', user.id)
    end

    def apply_history_limit(conversations, account)
      days = history_days(account)
      return conversations if days.zero?

      cutoff = days.days.ago
      conversations.where(
        'conversations.status != :resolved OR conversations.created_at >= :cutoff',
        resolved: Conversation.statuses[:resolved],
        cutoff: cutoff
      )
    end
  end

  def allowed?
    return true unless self.class.restricted_agent?(account_user)

    assignment_allowed? && history_allowed?
  end

  def account_user
    @account_user ||= self.class.find_account_user(user, account)
  end

  def assignment_allowed?
    conversation.assignee_id.nil? || conversation.assignee_id == user.id
  end

  def history_allowed?
    return true unless conversation.resolved?

    days = self.class.history_days(account)
    return true if days.zero?

    conversation.created_at >= days.days.ago
  end
end
