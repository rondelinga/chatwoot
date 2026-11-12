require 'rails_helper'

RSpec.describe ChatQueue::Agents::OnlineAgentsService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:least_active) { create(:user, account: account, role: :agent) }
  let(:earlier_closed) { create(:user, account: account, role: :agent) }
  let(:recently_closed) { create(:user, account: account, role: :agent) }
  let(:offline) { create(:user, account: account, role: :agent) }

  before do
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(
      least_active.id.to_s => 'online',
      earlier_closed.id.to_s => 'online',
      recently_closed.id.to_s => 'online',
      offline.id.to_s => 'busy'
    )
    [least_active, earlier_closed, recently_closed, offline].each do |agent|
      create(:inbox_member, inbox: inbox, user: agent)
    end
  end

  it 'sorts by fewest open chats, then by the oldest resolved update' do
    seed_workload

    expect(described_class.new(account: account).list).to eq(
      [least_active.id, earlier_closed.id, recently_closed.id]
    )
  end

  it 'reads open counts and last closed times in two grouped queries' do
    seed_workload
    statements = conversation_statements { described_class.new(account: account).list }
    grouped = statements.grep(/GROUP BY/i)

    expect(grouped.size).to eq(2)
    expect(grouped).to include(a_string_matching(/COUNT\(/i), a_string_matching(/MAX\(/i))
    expect(statements).not_to include(a_string_matching(/assignee_id" = /))
  end

  it 'returns an empty list without querying conversations when nobody is online' do
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(nil)
    result = nil
    statements = conversation_statements { result = described_class.new(account: account).list }

    expect(result).to eq([])
    expect(statements).to eq([])
  end

  it 'keeps only online members of the given team and tier' do
    team = create(:team, account: account)
    create(:team_member, team: team, user: recently_closed, assignment_tier: :backup)
    create(:team_member, team: team, user: earlier_closed, assignment_tier: :primary)
    create(:team_member, team: team, user: offline, assignment_tier: :backup)

    expect(described_class.new(account: account, team_id: team.id, assignment_tier: :backup).list).to eq(
      [recently_closed.id]
    )
  end

  def seed_workload
    seed_open_chats
    seed_resolved_chats
    seed_other_account_chat
  end

  def seed_open_chats
    create(:conversation, account: account, inbox: inbox, assignee: least_active, status: :pending)
    create(:conversation, account: account, inbox: inbox, assignee: offline, status: :open)
    2.times { create(:conversation, account: account, inbox: inbox, assignee: earlier_closed, status: :open) }
    2.times { create(:conversation, account: account, inbox: inbox, assignee: recently_closed, status: :open) }
  end

  def seed_resolved_chats
    resolve_at(earlier_closed, 5.hours.ago)
    resolve_at(earlier_closed, 3.hours.ago)
    resolve_at(recently_closed, 1.hour.ago)
  end

  def seed_other_account_chat
    other_account = create(:account)
    other_inbox = create(:inbox, account: other_account)
    create(:conversation, account: other_account, inbox: other_inbox, assignee: least_active, status: :open)
  end

  def resolve_at(agent, time)
    conversation = create(:conversation, account: account, inbox: inbox, assignee: agent, status: :resolved)
    conversation.update_columns(updated_at: time) # rubocop:disable Rails/SkipsModelValidations
  end

  def conversation_statements(&)
    statements = []
    ActiveSupport::Notifications.subscribed(->(*, payload) { statements << payload[:sql] }, 'sql.active_record', &)
    statements.grep(/FROM "conversations"/)
  end
end
