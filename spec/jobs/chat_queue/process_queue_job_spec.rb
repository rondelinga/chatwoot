require 'rails_helper'

RSpec.describe ChatQueue::ProcessQueueJob, type: :job do
  let(:account) { create(:account, queue_enabled: true) }
  let(:inbox) { create(:inbox, account: account, enable_auto_assignment: true) }
  let(:agent_a) { create(:user, account: account, role: :agent) }
  let(:agent_b) { create(:user, account: account, role: :agent) }
  let(:team_a) { create(:team, account: account) }
  let(:team_b) { create(:team, account: account) }
  let(:policy) { create(:assignment_policy, account: account, assignment_order: :least_busy) }

  before do
    create(:inbox_member, inbox: inbox, user: agent_a)
    create(:inbox_member, inbox: inbox, user: agent_b)
    create(:team_member, team: team_a, user: agent_a)
    create(:team_member, team: team_b, user: agent_b)
    create(:inbox_assignment_policy, inbox: inbox, assignment_policy: policy)
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(
      { agent_b.id.to_s => 'online', agent_a.id.to_s => 'offline' }
    )
  end

  def enqueue(team, queued_at:)
    # Team is set with the queued status: creating it with a team would let the queue enqueue it on its own
    conversation = create(:conversation, account: account, inbox: inbox, assignee: agent_b)
    conversation.update_columns( # rubocop:disable Rails/SkipsModelValidations
      assignee_id: nil,
      status: Conversation.statuses[:queued],
      team_id: team.id
    )
    ConversationQueue.create!(
      account: account,
      inbox: inbox,
      conversation: conversation,
      status: :waiting,
      queued_at: queued_at
    )
    conversation
  end

  it 'assigns a later team while an earlier team has no free agent' do
    stuck = enqueue(team_a, queued_at: 2.hours.ago)
    ready = enqueue(team_b, queued_at: 1.hour.ago)

    described_class.perform_now(account.id)

    expect(stuck.reload.assignee).to be_nil
    expect(stuck.status).to eq('queued')
    expect(ready.reload.assignee).to eq(agent_b)
    expect(ready.status).to eq('open')
  end

  it 'keeps order inside one team' do
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(agent_b.id.to_s => 'online')
    account.update!(active_chat_limit_enabled: true, active_chat_limit_value: 1)
    older = enqueue(team_b, queued_at: 2.hours.ago)
    newer = enqueue(team_b, queued_at: 1.hour.ago)

    described_class.perform_now(account.id)

    expect(older.reload.assignee).to eq(agent_b)
    expect(newer.reload.assignee).to be_nil
    expect(newer.status).to eq('queued')
  end
end
