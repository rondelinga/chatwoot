# Skip the generic assignee activity when a force transfer writes its own message.
Rails.application.config.to_prepare do
  next if AssignmentHandler <= ForceTransferAssignmentGuard

  AssignmentHandler.prepend(ForceTransferAssignmentGuard)
end
