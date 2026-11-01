require 'rails_helper'

# Verification matrix: assignment paths x limits (global / policy / personal).
# Each example creates a fresh unassigned conversation through the real entry point
# of the path under test and asserts who (if anyone) gets it.
RSpec.describe 'Auto assignment limits matrix', type: :model do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:agent_a) { create(:user, account: account, role: :agent, name: 'Agent A') }
  let(:agent_b) { create(:user, account: account, role: :agent, name: 'Agent B') }
  let(:online_agents) { [agent_a] }

  before do
    create(:inbox_member, inbox: inbox, user: agent_a)
    create(:inbox_member, inbox: inbox, user: agent_b)
    allow(OnlineStatusTracker).to receive(:get_available_users) { online_agents.to_h { |u| [u.id.to_s, 'online'] } }
  end

  # Seeds `count` conversations already assigned to agent in the main inbox.
  def give_chats(agent, count, status: :open)
    Array.new(count) do
      conversation = create(:conversation, account: account, inbox: inbox, assignee: agent)
      conversation.update_columns(status: Conversation.statuses[status]) # rubocop:disable Rails/SkipsModelValidations
      conversation
    end
  end

  def apply_global_limit(value)
    account.update!(active_chat_limit_enabled: true, active_chat_limit_value: value)
  end

  def apply_personal_limit(agent, value)
    agent.account_users.find_by(account: account).update!(active_chat_limit_enabled: true, active_chat_limit: value)
  end

  # Capacity policies are an Assignment V2 feature; legacy and queue inboxes use the inbox limit.
  # Both limits exist only in Enterprise.
  def apply_policy_limit(agent, value)
    if %i[v1 queue].include?(path)
      inbox.update!(auto_assignment_config: { 'max_assignment_limit' => value })
    else
      capacity_policy = create(:agent_capacity_policy, account: account)
      create(:inbox_capacity_limit, inbox: inbox, agent_capacity_policy: capacity_policy, conversation_limit: value)
      agent.account_users.find_by(account: account).update!(agent_capacity_policy: capacity_policy)
    end
  end

  def configure_path
    case path
    when :v1
      nil
    when :queue
      account.update!(queue_enabled: true)
    else
      order = { v2_round_robin: 0, v2_balanced: 1, v2_least_busy: 2 }.fetch(path)
      policy = create(:assignment_policy, account: account, assignment_order: order, fair_distribution_limit: 100)
      create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)
      account.enable_features('assignment_v2', 'advanced_assignment')
      account.save!
    end
  end

  # Creates a new unassigned open conversation and runs the path's assignment.
  def assign_new_conversation(team: nil)
    conversation = create(:conversation, account: account, inbox: inbox, assignee: nil, team: team)
    AutoAssignment::AssignmentService.new(inbox: inbox.reload).perform_bulk_assignment(limit: 10) if path.to_s.start_with?('v2')
    conversation.reload
  end

  # balanced exists only in Enterprise
  assignment_paths = %i[v1 v2_round_robin v2_least_busy queue]
  assignment_paths.insert(2, :v2_balanced) if ChatwootApp.enterprise?

  assignment_paths.each do |assignment_path|
    context "with path #{assignment_path}" do
      let(:path) { assignment_path }

      before { configure_path }

      it 'assigns when no limits are set (sanity)' do
        give_chats(agent_a, 3)
        expect(assign_new_conversation.assignee).to eq(agent_a)
      end

      it 'C(i) global limit only: agent at global limit is skipped' do
        apply_global_limit(2)
        give_chats(agent_a, 2)
        expect(assign_new_conversation.assignee).to be_nil
      end

      it 'C(i) global limit only: agent below global limit is assigned' do
        apply_global_limit(2)
        give_chats(agent_a, 1)
        expect(assign_new_conversation.assignee).to eq(agent_a)
      end

      it 'C(ii) policy limit only: agent at policy limit is skipped', if: ChatwootApp.enterprise? do
        apply_policy_limit(agent_a, 1)
        give_chats(agent_a, 1)
        expect(assign_new_conversation.assignee).to be_nil
      end

      it 'C(iii) personal limit only: agent at personal limit is skipped' do
        apply_personal_limit(agent_a, 1)
        give_chats(agent_a, 1)
        expect(assign_new_conversation.assignee).to be_nil
      end

      it 'C(iii) personal limit only: agent below personal limit is assigned' do
        apply_personal_limit(agent_a, 2)
        give_chats(agent_a, 1)
        expect(assign_new_conversation.assignee).to eq(agent_a)
      end

      it 'C(iv) personal higher than global: agent may exceed global' do
        apply_global_limit(1)
        apply_personal_limit(agent_a, 3)
        give_chats(agent_a, 2)
        expect(assign_new_conversation.assignee).to eq(agent_a)
      end

      it 'C(iv) personal lower than global: capped at personal' do
        apply_global_limit(5)
        apply_personal_limit(agent_a, 1)
        give_chats(agent_a, 1)
        expect(assign_new_conversation.assignee).to be_nil
      end

      it 'C(iv) personal higher than policy: personal replaces policy limit', if: ChatwootApp.enterprise? do
        apply_policy_limit(agent_a, 1)
        apply_personal_limit(agent_a, 3)
        give_chats(agent_a, 1)
        expect(assign_new_conversation.assignee).to eq(agent_a)
      end

      it 'C(iv) personal lower than policy: capped at personal', if: ChatwootApp.enterprise? do
        apply_policy_limit(agent_a, 5)
        apply_personal_limit(agent_a, 1)
        give_chats(agent_a, 1)
        expect(assign_new_conversation.assignee).to be_nil
      end

      it 'D personal limit 0: never assigned' do
        apply_personal_limit(agent_a, 0)
        expect(assign_new_conversation.assignee).to be_nil
      end

      it 'D global limit 0: never assigned' do
        apply_global_limit(0)
        expect(assign_new_conversation.assignee).to be_nil
      end

      it 'D pending/snoozed chats do not count toward limit (documents behaviour)' do
        apply_personal_limit(agent_a, 1)
        give_chats(agent_a, 1, status: :pending)
        give_chats(agent_a, 1, status: :snoozed)
        expect(assign_new_conversation.assignee).to eq(agent_a)
      end

      it 'A(6) tiers: backup used only when every primary is at its limit (global limit)' do
        team = create(:team, account: account, allow_auto_assign: true, assignment_tiers_enabled: true)
        create(:team_member, team: team, user: agent_a, assignment_tier: :primary)
        create(:team_member, team: team, user: agent_b, assignment_tier: :backup)
        online_agents.push(agent_b)
        apply_global_limit(1)
        give_chats(agent_a, 1)
        expect(assign_new_conversation(team: team).assignee).to eq(agent_b)
      end

      it 'A(6) tiers: backup used only when every primary is at its limit (personal limit)' do
        team = create(:team, account: account, allow_auto_assign: true, assignment_tiers_enabled: true)
        create(:team_member, team: team, user: agent_a, assignment_tier: :primary)
        create(:team_member, team: team, user: agent_b, assignment_tier: :backup)
        online_agents.push(agent_b)
        apply_personal_limit(agent_a, 1)
        give_chats(agent_a, 1)
        expect(assign_new_conversation(team: team).assignee).to eq(agent_b)
      end

      it 'A(6) tiers: primary preferred even when backup is less busy' do
        team = create(:team, account: account, allow_auto_assign: true, assignment_tiers_enabled: true)
        create(:team_member, team: team, user: agent_a, assignment_tier: :primary)
        create(:team_member, team: team, user: agent_b, assignment_tier: :backup)
        online_agents.push(agent_b)
        give_chats(agent_a, 3)
        expect(assign_new_conversation(team: team).assignee).to eq(agent_a)
      end

      it 'A(6) tiers disabled: backup member is a normal candidate' do
        team = create(:team, account: account, allow_auto_assign: true, assignment_tiers_enabled: false)
        create(:team_member, team: team, user: agent_a, assignment_tier: :primary)
        create(:team_member, team: team, user: agent_b, assignment_tier: :backup)
        online_agents.replace([agent_b])
        expect(assign_new_conversation(team: team).assignee).to eq(agent_b)
      end

      it 'team restriction: non-team member never picked' do
        team = create(:team, account: account, allow_auto_assign: true)
        create(:team_member, team: team, user: agent_a)
        online_agents.push(agent_b)
        give_chats(agent_a, 3)
        expect(assign_new_conversation(team: team).assignee).to eq(agent_a)
      end
    end
  end
end
