# Override for AutoAssignment::AutoAssignmentHandler
# Adds queue-based assignment logic when account.queue_enabled?
# Original: app/models/concerns/auto_assignment_handler.rb
# Modified: 2026-07-02 — fix race between team-assignment automation and auto-assignment

Rails.application.config.to_prepare do
  module AutoAssignmentHandlerOverride
    private

    def run_auto_assignment
      return if skip_due_to_queue_status_change?
      return unless assignment_trigger_event?
      return unless should_run_auto_assignment?
      return if awaiting_team_assignment?

      if account.queue_enabled?
        handle_queue_assignment
      else
        handle_standard_assignment
      end
    end

    def assignment_trigger_event?
      conversation_status_changed_to_open? || (status == 'open' && saved_change_to_team_id?)
    end

    def skip_due_to_queue_status_change?
      saved_change_to_status? && status == 'open' && status_before_last_save == 'queued'
    end

    def should_run_auto_assignment?
      if account.queue_enabled?
        return false if status == 'queued'

        return true
      end

      return false unless inbox.enable_auto_assignment?

      assignee.blank? || inbox.members.exclude?(assignee)
    end

    def awaiting_team_assignment?
      team_id.blank? && team_routed_inbox?
    end

    def team_routed_inbox?
      @team_routed_inbox = inbox.inbox_teams.exists? if @team_routed_inbox.nil?
      @team_routed_inbox
    end

    def handle_queue_assignment
      return if team_id.blank? && team_routed_inbox?

      reconcile_invalid_queue_state

      queue_service = ChatQueue::QueueService.new(account: account)

      return if queued_or_assigned?

      clear_assignee_if_present

      if queue_empty_for?(self)
        handle_direct_or_queued_assignment(queue_service)
      else
        queue_service.add_to_queue(self)
      end
    end

    def reconcile_invalid_queue_state
      return unless account.queue_enabled?
      return unless queued? && (assignee_id.present? || assignee_agent_bot_id.present?)

      update!(status: :open)
    end

    def handle_standard_assignment
      return if assignee.present?

      allowed_ids = inbox.member_ids_with_assignment_capacity || []
      return if allowed_ids.empty?

      assignee = ::AutoAssignment::AgentAssignmentService.new(
        conversation: self,
        allowed_agent_ids: allowed_ids
      ).find_assignee

      update!(assignee: assignee) if assignee
    end

    def queued_or_assigned?
      queued? || assignee_id.present? || assignee_agent_bot_id.present?
    end

    # rubocop:disable Rails/SkipsModelValidations
    def clear_assignee_if_present
      updates = {}
      updates[:assignee_id] = nil if assignee_id.present?
      updates[:assignee_agent_bot_id] = nil if assignee_agent_bot_id.present?
      update_columns(updates) if updates.any?
    end
    # rubocop:enable Rails/SkipsModelValidations

    def queue_empty_for?(conversation)
      ChatQueue::Queue::FetchService.new(account: account)

      scope = ConversationQueue
              .for_account(account.id)
              .waiting
              .joins(:conversation)

      if conversation.team_id.present?
        scope.where(conversations: { team_id: conversation.team_id }).none?
      else
        scope.where(conversations: { inbox_id: conversation.inbox_id }).none?
      end
    end

    def handle_direct_or_queued_assignment(queue_service)
      return queue_service.add_to_queue(self) unless assignee_id.nil?

      return if ChatQueue::Agents::TierAssignmentService.new(account: account, conversation: self).assign_primary_then_backup

      queue_service.add_to_queue(self)
    end
  end

  AutoAssignmentHandler.prepend(AutoAssignmentHandlerOverride)
end
