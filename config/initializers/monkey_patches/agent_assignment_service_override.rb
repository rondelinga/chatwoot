# Override for AutoAssignment::AgentAssignmentService
# Replaces round-robin with load-balanced selection with per-agent/global limits
Rails.application.config.to_prepare do
  AutoAssignment::AgentAssignmentService.prepend(AutoAssignment::AgentAssignmentServiceOverride)
end
