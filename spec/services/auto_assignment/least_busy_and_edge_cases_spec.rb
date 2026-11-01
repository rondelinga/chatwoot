require 'rails_helper'

# Verification: least_busy ordering (V2 bulk path), V2 tiers via bulk, and edge cases
# around the queue / periodic job / manual assignment.
RSpec.describe 'Least busy assignment and edge cases', type: :model do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:other_inbox) { create(:inbox, account: account, enable_auto_assignment: false) }
  let(:agent_a) { create(:user, account: account, role: :agent, name: 'Agent A') }
  let(:agent_b) { create(:user, account: account, role: :agent, name: 'Agent B') }
  let(:online_agents) { [agent_a, agent_b] }
  let(:assignment_order) { 2 }
  let(:policy) { create(:assignment_policy, account: account, assignment_order: assignment_order, fair_distribution_limit: 100) }

  before do
    create(:inbox_member, inbox: inbox, user: agent_a)
    create(:inbox_member, inbox: inbox, user: agent_b)
    create(:inbox_member, inbox: other_inbox, user: agent_a)
    create(:inbox_member, inbox: other_inbox, user: agent_b)
    allow(OnlineStatusTracker).to receive(:get_available_users) { online_agents.to_h { |u| [u.id.to_s, 'online'] } }
    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)
    account.enable_features('assignment_v2', 'advanced_assignment')
    account.save!
  end

  def give_chats(agent, count, status: :open, target_inbox: inbox, updated_at: nil)
    Array.new(count) do
      conversation = create(:conversation, account: account, inbox: target_inbox, assignee: agent)
      attrs = { status: Conversation.statuses[status] }
      attrs[:updated_at] = updated_at if updated_at
      conversation.update_columns(attrs) # rubocop:disable Rails/SkipsModelValidations
      conversation
    end
  end

  def new_unassigned(team: nil)
    conversation = create(:conversation, account: account, inbox: inbox, assignee: nil)
    conversation.update_columns(team_id: team.id) if team # rubocop:disable Rails/SkipsModelValidations
    conversation
  end

  def run_bulk
    AutoAssignment::AssignmentService.new(inbox: inbox.reload).perform_bulk_assignment(limit: 10)
  end

  describe 'B least_busy ordering' do
    it 'picks the agent with fewer open chats' do
      give_chats(agent_a, 2)
      give_chats(agent_b, 1)
      conversation = new_unassigned
      run_bulk
      expect(conversation.reload.assignee).to eq(agent_b)
    end

    it 'counts chats account-wide, not only in this inbox' do
      give_chats(agent_a, 3, target_inbox: other_inbox)
      give_chats(agent_b, 1)
      conversation = new_unassigned
      run_bulk
      expect(conversation.reload.assignee).to eq(agent_b)
    end

    it 'ranks by the same "active" definition the limits use (open only) - snoozed/pending must not make an agent look busier' do
      give_chats(agent_a, 3, status: :snoozed)
      give_chats(agent_b, 1)
      conversation = new_unassigned
      run_bulk
      expect(conversation.reload.assignee).to eq(agent_a)
    end

    it 'tie-break: agent who closed a chat least recently wins' do
      give_chats(agent_a, 1)
      give_chats(agent_b, 1)
      give_chats(agent_a, 1, status: :resolved, updated_at: 2.hours.ago)
      give_chats(agent_b, 1, status: :resolved, updated_at: 1.minute.ago)
      conversation = new_unassigned
      run_bulk
      expect(conversation.reload.assignee).to eq(agent_a)
    end

    it 'tie-break: agent who never closed a chat wins over one who did' do
      give_chats(agent_a, 1, status: :resolved, updated_at: 2.days.ago)
      conversation = new_unassigned
      run_bulk
      expect(conversation.reload.assignee).to eq(agent_b)
    end

    it 'ignores offline agents even when they are less busy' do
      online_agents.replace([agent_a])
      give_chats(agent_a, 2)
      conversation = new_unassigned
      run_bulk
      expect(conversation.reload.assignee).to eq(agent_a)
    end

    it 'ignores online agents that are not inbox members' do
      outsider = create(:user, account: account, role: :agent)
      online_agents.push(outsider)
      give_chats(agent_a, 1)
      give_chats(agent_b, 1)
      conversation = new_unassigned
      run_bulk
      expect(conversation.reload.assignee).to be_in([agent_a, agent_b])
    end

    it 'respects team restriction' do
      team = create(:team, account: account, allow_auto_assign: true)
      create(:team_member, team: team, user: agent_a)
      give_chats(agent_a, 3)
      conversation = new_unassigned(team: team)
      run_bulk
      expect(conversation.reload.assignee).to eq(agent_a)
    end

    it 're-counts between conversations of one bulk run (global limit 1, 3 conversations, 2 agents)' do
      account.update!(active_chat_limit_enabled: true, active_chat_limit_value: 1)
      conversations = Array.new(3) { new_unassigned }
      expect(run_bulk).to eq(2)
      expect(conversations.filter_map { |c| c.reload.assignee_id }).to contain_exactly(agent_a.id, agent_b.id)
    end
  end

  describe 'A(6) tiers through the V2 bulk path (team set without AssignmentHandler)' do
    let(:team) { create(:team, account: account, allow_auto_assign: true, assignment_tiers_enabled: true) }

    before do
      create(:team_member, team: team, user: agent_a, assignment_tier: :primary)
      create(:team_member, team: team, user: agent_b, assignment_tier: :backup)
    end

    [[0, 'round_robin'], [1, 'balanced'], [2, 'least_busy']].each do |order, name|
      context "with #{name}" do
        let(:assignment_order) { order }

        it 'primary first even if backup is less busy' do
          give_chats(agent_a, 3)
          conversation = new_unassigned(team: team)
          run_bulk
          expect(conversation.reload.assignee).to eq(agent_a)
        end

        it 'falls back to backup when primary is at the GLOBAL limit' do
          account.update!(active_chat_limit_enabled: true, active_chat_limit_value: 1)
          give_chats(agent_a, 1)
          conversation = new_unassigned(team: team)
          run_bulk
          expect(conversation.reload.assignee).to eq(agent_b)
        end

        it 'falls back to backup when primary is at the capacity POLICY limit' do
          capacity_policy = create(:agent_capacity_policy, account: account)
          create(:inbox_capacity_limit, inbox: inbox, agent_capacity_policy: capacity_policy, conversation_limit: 1)
          agent_a.account_users.find_by(account: account).update!(agent_capacity_policy: capacity_policy)
          give_chats(agent_a, 1)
          conversation = new_unassigned(team: team)
          run_bulk
          expect(conversation.reload.assignee).to eq(agent_b)
        end
      end
    end
  end

  describe 'team assignment through AssignmentHandler#ensure_assignee_is_from_team' do
    let(:team) { create(:team, account: account, allow_auto_assign: true) }

    before do
      create(:team_member, team: team, user: agent_a)
      account.update!(active_chat_limit_enabled: true, active_chat_limit_value: 1)
      give_chats(agent_a, 1)
    end

    it 'does not assign an agent at the global limit when the team is set via the API/automation' do
      conversation = new_unassigned
      conversation.update!(team: team)
      expect(conversation.reload.assignee).to be_nil
    end

    it 'in queue mode, a team change does not bypass the queue' do
      account.update!(queue_enabled: true)
      online_agents.replace([agent_a])
      agent_a.account_users.find_by(account: account).update!(active_chat_limit_enabled: true, active_chat_limit: 5)
      waiting = create(:conversation, account: account, inbox: inbox, assignee: nil)
      waiting.update_columns(status: Conversation.statuses[:queued]) # rubocop:disable Rails/SkipsModelValidations
      ConversationQueue.create!(account: account, inbox: inbox, conversation: waiting, status: :waiting, queued_at: 1.hour.ago, position: 1)
      later = new_unassigned
      later.update_columns(assignee_id: nil, status: Conversation.statuses[:open]) # rubocop:disable Rails/SkipsModelValidations
      later.reload.update!(team: team)
      expect(later.reload.assignee).to be_nil
    end
  end

  describe 'D edge cases' do
    it 'agent bot owned conversations are not taken by V2 bulk' do
      bot = create(:agent_bot, account: account)
      conversation = new_unassigned
      conversation.update_columns(assignee_agent_bot_id: bot.id) # rubocop:disable Rails/SkipsModelValidations
      run_bulk
      expect(conversation.reload.assignee).to be_nil
    end

    context 'with periodic V2 job and round_robin policy' do
      let(:assignment_order) { 0 }

      def run_periodic
        # creating the conversation already claimed the per-inbox in-flight gate for a job that never ran in test
        Redis::Alfred.delete(format(Redis::Alfred::AUTO_ASSIGNMENT_IN_FLIGHT_KEY, inbox_id: inbox.id))
        perform_enqueued_jobs(only: [AutoAssignment::PeriodicAssignmentJob, AutoAssignment::AssignmentJob]) do
          AutoAssignment::PeriodicAssignmentJob.perform_later
        end
      end

      it 'control: periodic job assigns an open unassigned conversation without queue' do
        conversation = new_unassigned
        run_periodic
        expect(conversation.reload.assignee).to be_present
      end

      it 'does not bypass the queue / global limit when queue mode is on' do
        account.update!(queue_enabled: true, active_chat_limit_enabled: true, active_chat_limit_value: 1)
        give_chats(agent_a, 1)
        give_chats(agent_b, 1)
        conversation = new_unassigned
        conversation.update_columns(assignee_id: nil, status: Conversation.statuses[:open]) # rubocop:disable Rails/SkipsModelValidations
        run_periodic
        expect(conversation.reload.assignee).to be_nil
      end

      it 'does not assign a conversation still awaiting team routing' do
        routing_team = create(:team, account: account)
        InboxTeam.create!(inbox: inbox, team: routing_team)
        conversation = new_unassigned
        expect(conversation.reload.assignee).to be_nil
        run_periodic
        expect(conversation.reload.assignee).to be_nil
      end
    end

    context 'with ChatQueue::ProcessQueueJob' do
      before do
        account.update!(queue_enabled: true)
        online_agents.replace([agent_a])
        agent_a.account_users.find_by(account: account).update!(active_chat_limit_enabled: true, active_chat_limit: 1)
      end

      it 'keeps the conversation queued while the only agent is at the personal limit, assigns once a slot frees' do
        busy = give_chats(agent_a, 1).first
        queued = create(:conversation, account: account, inbox: inbox, assignee: nil)
        expect(queued.reload.status).to eq('queued')

        ChatQueue::ProcessQueueJob.perform_now(account.id)
        expect(queued.reload.assignee).to be_nil

        busy.update_columns(status: Conversation.statuses[:resolved]) # rubocop:disable Rails/SkipsModelValidations
        ChatQueue::ProcessQueueJob.perform_now(account.id)
        expect(queued.reload.assignee).to eq(agent_a)
        expect(queued.status).to eq('open')
      end

      it 'respects the agent capacity policy of an Assignment V2 inbox' do
        account_user = agent_a.account_users.find_by(account: account)
        capacity_policy = create(:agent_capacity_policy, account: account)
        create(:inbox_capacity_limit, inbox: inbox, agent_capacity_policy: capacity_policy, conversation_limit: 1)
        account_user.update!(active_chat_limit_enabled: false, agent_capacity_policy: capacity_policy)
        give_chats(agent_a, 1)
        queued = create(:conversation, account: account, inbox: inbox, assignee: nil)
        ChatQueue::ProcessQueueJob.perform_now(account.id)
        expect(queued.reload.assignee).to be_nil
      end

      it 'respects the global limit for agents without a personal limit' do
        agent_a.account_users.find_by(account: account).update!(active_chat_limit_enabled: false)
        account.update!(active_chat_limit_enabled: true, active_chat_limit_value: 1)
        give_chats(agent_a, 1)
        queued = create(:conversation, account: account, inbox: inbox, assignee: nil)
        ChatQueue::ProcessQueueJob.perform_now(account.id)
        expect(queued.reload.assignee).to be_nil
      end
    end

    it 'manual assignment ignores limits (documents behaviour)' do
      agent_a.account_users.find_by(account: account).update!(active_chat_limit_enabled: true, active_chat_limit: 0)
      conversation = new_unassigned
      Conversations::AssignmentService.new(conversation: conversation.reload, assignee_id: agent_a.id).perform
      expect(conversation.reload.assignee).to eq(agent_a)
    end
  end
end
