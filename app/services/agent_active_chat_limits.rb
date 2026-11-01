# Active chat limits for auto-assignment, counted on open conversations.
# The personal limit (`account_users.active_chat_limit`) sits above every other cap: when it is
# enabled it replaces the account limit, the inbox auto-assignment limit and the agent capacity
# policy. Agents without a personal limit keep the policy and inbox caps and also stay under the
# account limit (`accounts.active_chat_limit_value`).
class AgentActiveChatLimits
  def self.limit_for(account, user_id)
    personal_limit(account, user_id) || account_limit_value(account)
  end

  def self.personal_limit(account, user_id)
    personal_limit_map(account)[user_id.to_i]
  end

  def self.limited?(account, user_id)
    !limit_for(account, user_id).nil?
  end

  def self.under_limit?(account, user_id)
    over_limit_ids(account, [user_id]).empty?
  end

  # Locks the agent's account_user row before re-counting, so concurrent assignments to the
  # same agent cannot both pass the check. Must run inside the assigning transaction.
  def self.claim_slot?(account, user_id)
    return true unless limited?(account, user_id)

    AccountUser.lock.find_by(account_id: account.id, user_id: user_id)
    under_limit?(account, user_id)
  end

  def self.over_limit_ids(account, user_ids)
    ids = user_ids.map(&:to_i)
    personal_limits = personal_limit_map(account)
    account_limit = account_limit_value(account)
    limited_ids = ids.select { |id| personal_limits.key?(id) || !account_limit.nil? }
    return [] if limited_ids.empty?

    counts = open_counts(account, limited_ids)
    limited_ids.select do |id|
      limit = personal_limits[id] || account_limit
      counts.fetch(id, 0) >= limit
    end
  end

  def self.open_count(account, user_id)
    open_counts(account, [user_id]).fetch(user_id.to_i, 0)
  end

  # filtered_ids already passed the inbox and capacity policy filters. Agents with a personal
  # limit are judged only by that limit, using candidate_ids (the pool before those filters).
  def self.apply(account, filtered_ids, candidate_ids)
    limits = personal_limit_map(account)
    filtered = filtered_ids.map(&:to_i)
    without_personal_limit = filtered.reject { |id| limits.key?(id) }
    with_personal_limit = candidate_ids.map(&:to_i).select { |id| limits.key?(id) }

    (without_personal_limit + with_personal_limit).uniq - over_limit_ids(account, without_personal_limit + with_personal_limit)
  end

  def self.filter_members(account, members)
    over_limit = over_limit_ids(account, members.map { |member| member_user_id(member) })
    return members if over_limit.empty?

    members.reject { |member| over_limit.include?(member_user_id(member)) }
  end

  def self.account_limit_value(account)
    return unless account.active_chat_limit_enabled? && account.active_chat_limit.present?

    account.active_chat_limit.to_i
  end

  def self.personal_limit_map(account)
    account.account_users
           .where(active_chat_limit_enabled: true)
           .where.not(active_chat_limit: nil)
           .pluck(:user_id, :active_chat_limit)
           .to_h
           .transform_values(&:to_i)
  end

  def self.open_counts(account, user_ids)
    ids = user_ids.map(&:to_i).uniq
    return {} if ids.empty?

    Conversation.where(account_id: account.id, assignee_id: ids, status: :open).group(:assignee_id).count
  end

  def self.member_user_id(member)
    member.is_a?(User) ? member.id : member.user_id
  end

  def self.install!
    prepend_once(Inbox, InboxFilter)
    prepend_once(AutoAssignment::AgentSelector, SelectorFilter)
    prepend_once(Api::V1::Accounts::AgentsController, AgentsControllerExtension)
    AccountUser.include(AccountUserValidation) unless AccountUser.include?(AccountUserValidation)
    return unless ChatwootApp.enterprise?

    prepend_once(Enterprise::AutoAssignment::CapacityService, CapacityFilter)
  end

  def self.prepend_once(klass, mod)
    klass.prepend(mod) unless klass.ancestors.include?(mod)
  end

  module InboxFilter
    def member_ids_with_assignment_capacity
      filtered_ids = super
      candidates = if auto_assignment_v2_enabled?
                     available_agents.map(&:user_id)
                   else
                     members.ids
                   end
      AgentActiveChatLimits.apply(account, filtered_ids, candidates)
    end
  end

  module SelectorFilter
    def select(members)
      super(AgentActiveChatLimits.filter_members(inbox.account, Array(members)))
    end
  end

  module CapacityFilter
    def agent_has_capacity?(user, inbox)
      limit = AgentActiveChatLimits.personal_limit(inbox.account, user.id)
      return AgentActiveChatLimits.open_count(inbox.account, user.id) < limit unless limit.nil?

      super
    end
  end

  module AgentsControllerExtension
    private

    def account_user_attributes
      super + [:active_chat_limit, :active_chat_limit_enabled]
    end

    def allowed_agent_params
      super + [:active_chat_limit, :active_chat_limit_enabled]
    end
  end

  module AccountUserValidation
    extend ActiveSupport::Concern

    included do
      validates :active_chat_limit,
                numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                presence: true,
                if: :active_chat_limit_enabled?
    end
  end
end
