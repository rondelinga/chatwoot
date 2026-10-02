# Override for AutoAssignment::AutoAssignmentHandler
# Adds queue-based assignment logic when account.queue_enabled?
Rails.application.config.to_prepare do
  AutoAssignmentHandler.prepend(AutoAssignmentHandlerOverride)
end
