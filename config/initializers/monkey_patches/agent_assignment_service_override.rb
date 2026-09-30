# Override for AutoAssignment::AgentAssignmentService
# Replaces round-robin with load-balanced selection with per-agent/global limits
# Original: app/services/auto_assignment/agent_assignment_service.rb
# Modified: 2026-05-02

Rails.application.config.to_prepare do
  module AutoAssignment
    module AgentAssignmentServiceOverride
      def find_assignee
        assignee = find_assignee_for_tier(:primary)
        return assignee if assignee

        return if primary_tier_has_capacity?

        find_assignee_for_tier(:backup)
      end

      private

      def find_assignee_for_tier(tier)
        ids = tier_filtered_agent_ids(tier)
        return if ids.blank?

        counts = active_chat_counts_for(ids)
        available_ids = filter_agents_below_limit(ids, counts)
        return if available_ids.blank?

        min_count = counts.slice(*available_ids).values.min
        least_busy = counts.select { |id, c| available_ids.include?(id) && c == min_count }.keys

        return User.find_by(id: least_busy.first) if least_busy.size == 1

        last_closed = last_closed_chat_times_for(least_busy)
        selected_id = pick_least_recent_assigned(least_busy, counts, last_closed)
        User.find_by(id: selected_id)
      end

      def primary_tier_has_capacity?
        ids = tier_filtered_agent_ids(:primary)
        return false if ids.blank?

        counts = active_chat_counts_for(ids)
        filter_agents_below_limit(ids, counts).present?
      end

      def tier_filtered_agent_ids(tier)
        ids = allowed_online_agent_ids || []
        return ids if conversation.team_id.blank?

        team_tier_ids = TeamMember
                        .where(team_id: conversation.team_id, assignment_tier: tier)
                        .pluck(:user_id)
        ids & team_tier_ids
      end

      def active_chat_counts_for(agent_ids)
        Conversation
          .where(assignee_id: agent_ids, account_id: conversation.account_id)
          .where.not(status: :resolved)
          .group(:assignee_id)
          .count
          .tap { |h| agent_ids.each { |id| h[id] ||= 0 } }
      end

      def filter_agents_below_limit(agent_ids, counts)
        agent_ids.reject { |id| agent_at_or_over_limit?(id, counts) }
      end

      def agent_at_or_over_limit?(agent_id, counts)
        limit = effective_limit_for_agent(agent_id)
        return false if limit.nil?

        (counts[agent_id] || 0) >= limit
      end

      def effective_limit_for_agent(agent_id)
        account = conversation.account
        account_user = AccountUser.find_by(account_id: account.id, user_id: agent_id)

        if account_user&.active_chat_limit_enabled? && account_user.active_chat_limit.present?
          return account_user.active_chat_limit.to_i
        end

        if account.active_chat_limit_enabled? && account.active_chat_limit.present?
          return account.active_chat_limit.to_i
        end

        nil
      end

      def last_closed_chat_times_for(agent_ids)
        Conversation
          .where(assignee_id: agent_ids, status: :resolved)
          .group(:assignee_id)
          .pluck(:assignee_id, Arel.sql('MAX(updated_at)'))
          .to_h
      end

      def pick_least_recent_assigned(agent_ids, counts, last_closed_times)
        stats = agent_ids.map do |id|
          { id: id, active: counts[id] || 0, last_closed: last_closed_times[id] || Time.zone.at(0) }
        end

        stats.sort_by { |s| [s[:active], s[:last_closed]] }.first[:id]
      end

      # Перекрываем allowed_online_agent_ids — в оригинале ids строки из Redis,
      # новая логика работает с integer, нужна явная конвертация
      def allowed_online_agent_ids
        online_ids = online_agent_ids.map(&:to_i)
        allowed_ids = allowed_agent_ids.map(&:to_i)
        @allowed_online_agent_ids ||= (online_ids & allowed_ids)
      end
    end
  end

  AutoAssignment::AgentAssignmentService.prepend(AutoAssignment::AgentAssignmentServiceOverride)
end
