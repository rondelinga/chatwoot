# Override for AutoAssignment::AutoAssignmentHandler
# Adds queue-based assignment logic when account.queue_enabled?
# Original: app/models/concerns/auto_assignment_handler.rb
# Modified: 2026-07-02 — fix race between team-assignment automation and auto-assignment
module AutoAssignmentHandlerOverride
  include AutoAssignmentHandlerQueue

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
    return queue_assignment_eligible? if account.queue_enabled?
    return false unless inbox.enable_auto_assignment?

    assignee.blank? || inbox.members.exclude?(assignee)
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

  def handle_standard_assignment
    return if assignee.present?

    allowed_ids = allowed_agent_ids_for_assignment
    return if allowed_ids.empty?

    new_assignee = ::AutoAssignment::AgentAssignmentService.new(
      conversation: self,
      allowed_agent_ids: allowed_ids
    ).find_assignee

    update!(assignee: new_assignee) if new_assignee
  end

  def allowed_agent_ids_for_assignment
    ids = inbox.member_ids_with_assignment_capacity || []
    return ids if team_id.blank? || team.blank? || team.allow_auto_assign.blank?

    ids & team.members.ids
  end
end
