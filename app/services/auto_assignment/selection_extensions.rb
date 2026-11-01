# Routes upstream auto-assignment through AutoAssignment::AgentSelector (assignment policy
# order incl. least busy, team tiers, active chat limits) without editing the upstream services.
module AutoAssignment::SelectionExtensions
  def self.install!
    AgentActiveChatLimits.prepend_once(AutoAssignment::AgentAssignmentService, LegacyAssignment)
    AgentActiveChatLimits.prepend_once(AutoAssignment::AssignmentService, BulkAssignment)
    AgentActiveChatLimits.prepend_once(Api::V1::Accounts::TeamsController, TeamsControllerExtension)
  end

  # Selects with AgentSelector and claims the agent's limit slot under a row lock.
  def self.select_and_claim(inbox:, conversation:, candidates:)
    remaining = Array(candidates)
    while remaining.any?
      agent = AutoAssignment::AgentSelector.new(inbox: inbox, conversation: conversation).select(remaining)
      return if agent.nil?
      return agent if AgentActiveChatLimits.claim_slot?(inbox.account, agent.id)

      remaining = remaining.reject { |candidate| AgentActiveChatLimits.member_user_id(candidate) == agent.id }
    end
  end

  # Legacy (V1) path: AutoAssignment::AgentAssignmentService
  module LegacyAssignment
    def find_assignee
      AutoAssignment::SelectionExtensions.select_and_claim(
        inbox: conversation.inbox,
        conversation: conversation,
        candidates: User.where(id: allowed_online_agent_ids).to_a
      )
    end
  end

  # Assignment V2 path: AutoAssignment::AssignmentService (+ Enterprise prepend)
  module BulkAssignment
    SelectorAdapter = Struct.new(:inbox, :conversation) do
      def select_agent(agents)
        AutoAssignment::AgentSelector.new(inbox: inbox, conversation: conversation).select(agents)
      end
    end

    # Queued accounts assign through the chat queue, which keeps queue order and limits
    def perform_bulk_assignment(limit: 100)
      return 0 if inbox.account.queue_enabled?

      super
    end

    private

    def perform_for_conversation(conversation)
      @selecting_for = conversation
      super
    ensure
      @selecting_for = nil
    end

    # Both upstream selectors are replaced: AgentSelector picks the order from the policy
    def round_robin_selector
      SelectorAdapter.new(inbox, @selecting_for)
    end

    def balanced_selector
      SelectorAdapter.new(inbox, @selecting_for)
    end

    # The limit slot stays locked until the assignment commits. Upstream resets
    # Current.executed_by in super, before this outer transaction commits, so keep it
    # set here for the after_commit broadcasts (automatic assignment provenance).
    def claim_and_assign(conversation, agent)
      Conversation.transaction do
        next false unless AgentActiveChatLimits.claim_slot?(inbox.account, agent.id)

        super.tap { Current.executed_by = inbox.assignment_policy || inbox }
      end
    ensure
      Current.executed_by = nil
    end
  end

  module TeamsControllerExtension
    private

    def team_params
      super.merge(params.require(:team).permit(:assignment_tiers_enabled))
    end
  end
end
