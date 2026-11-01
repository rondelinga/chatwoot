# Keeps routing and the queue in front of Chatwoot assignment.
# Agent choice itself stays in upstream round robin / balanced.
# Original: app/models/concerns/auto_assignment_handler.rb
module AutoAssignmentHandlerOverride
  include AutoAssignmentHandlerQueue

  private

  def run_legacy_auto_assignment
    return if account.queue_enabled?
    return if awaiting_team_assignment?

    # Runs before Conversation's own before_save that drops the bot on pending -> open,
    # so drop it here first or the conversation is skipped as bot-owned and left unassigned
    clear_bot_assignee_when_leaving_pending
    return run_legacy_team_change_assignment if team_changing_without_status_change?

    super
  end

  # Same save as the team change (like upstream's status path): a follow-up save would
  # hide the team change from after_commit callbacks (activity message, TEAM_CHANGED)
  def run_legacy_team_change_assignment
    return if inbox.auto_assignment_v2_enabled?
    return unless team_change_needs_assignee?

    AutoAssignment::AgentAssignmentService.new(conversation: self, allowed_agent_ids: legacy_allowed_agent_ids).assign_under_lock
  end

  # Team changes in queued accounts are assigned by the queue (run_queue_assignment), in queue order
  def find_assignee_from_team
    return if account.queue_enabled?

    super
  end

  def run_auto_assignment
    return if skip_due_to_queue_status_change?
    return if awaiting_team_assignment?

    if account.queue_enabled?
      run_queue_assignment
    elsif team_changed_without_status_change?
      run_team_change_assignment
    else
      super
    end
  end

  def run_queue_assignment
    return unless assignment_trigger_event?
    return unless queue_assignment_eligible?

    handle_queue_assignment
  end

  # V2 only; legacy team changes are assigned in run_legacy_auto_assignment
  def run_team_change_assignment
    return unless inbox.auto_assignment_v2_enabled?
    return unless team_change_needs_assignee?

    AutoAssignment::AssignmentJob.enqueue_for_inbox(inbox.id)
  end

  def team_change_needs_assignee?
    return false unless inbox.enable_auto_assignment?
    return false if assignee_agent_bot_id.present?

    assignee.blank? || inbox.members.exclude?(assignee)
  end

  def assignment_trigger_event?
    conversation_status_changed_to_open? || team_changed_without_status_change?
  end

  def team_changed_without_status_change?
    status == 'open' && saved_change_to_team_id? && !saved_change_to_status?
  end

  def team_changing_without_status_change?
    open? && !new_record? && will_save_change_to_team_id? && !will_save_change_to_status?
  end

  def skip_due_to_queue_status_change?
    saved_change_to_status? && status == 'open' && status_before_last_save == 'queued'
  end

  def should_run_auto_assignment?
    return queue_assignment_eligible? if account.queue_enabled?

    super
  end

  def queue_assignment_eligible?
    status != 'queued'
  end

  def awaiting_team_assignment?
    team_id.blank? && team_routed_inbox?
  end

  def team_routed_inbox?
    @team_routed_inbox = inbox.inbox_teams.exists? if @team_routed_inbox.nil?
    @team_routed_inbox
  end
end
