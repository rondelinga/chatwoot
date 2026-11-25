# Force transfer writes its own activity message with both operators.
# Skip the generic assignee activity for that save.
module ForceTransferAssignmentGuard
  private

  def process_assignment_activities
    return if instance_variable_get(:@skip_assignee_activity)

    super
  end
end
