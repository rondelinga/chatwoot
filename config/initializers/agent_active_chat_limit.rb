# frozen_string_literal: true

Rails.application.config.to_prepare do
  AgentActiveChatLimits.install!
  AutoAssignment::SelectionExtensions.install!
  AutoAssignment::AssignmentJobRerun.install!
end
