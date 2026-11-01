class ChatQueue::Agents::TierAssignmentService
  pattr_initialize [:account!, :conversation!]

  def assign_primary_then_backup
    agent = ChatQueue::Agents::SelectorService.new(account: account).pick_best_agent_for(conversation)
    return false unless agent

    ChatQueue::DirectAssignmentService.new(
      account: account,
      conversation: conversation,
      agent: agent
    ).assign!.present?
  end
end
