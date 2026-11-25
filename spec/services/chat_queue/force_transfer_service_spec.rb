require 'rails_helper'

RSpec.describe ChatQueue::ForceTransferService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:other_team) { create(:team, account: account) }
  let(:current_agent) { create(:user, account: account, role: :agent) }
  let(:teammate) { create(:user, account: account, role: :agent) }
  let(:outsider) { create(:user, account: account, role: :agent) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: current_agent, team: team) }

  before do
    create(:inbox_member, inbox: inbox, user: current_agent)
    create(:inbox_member, inbox: inbox, user: teammate)
    create(:inbox_member, inbox: inbox, user: outsider)
    create(:team_member, team: team, user: current_agent)
    create(:team_member, team: team, user: teammate)
    create(:team_member, team: other_team, user: outsider)
  end

  def transfer
    described_class.new(conversation: conversation, current_user: current_agent).perform
  end

  def online(*agents)
    allow(OnlineStatusTracker).to receive(:get_available_users).and_return(
      agents.to_h { |agent| [agent.id.to_s, 'online'] }
    )
  end

  it 'transfers to the least loaded teammate and leaves other teams alone' do
    busier = create(:user, account: account, role: :agent)
    create(:inbox_member, inbox: inbox, user: busier)
    create(:team_member, team: team, user: busier)
    create(:conversation, account: account, inbox: inbox, assignee: busier, team: team)
    online(teammate, busier, outsider)

    result = transfer

    expect(result[:success]).to be(true)
    expect(conversation.reload.assignee).to eq(teammate)
    expect(conversation.messages.activity.last.content).to eq(
      "Conversation was transferred from #{current_agent.name} to #{teammate.name}"
    )
  end

  it 'writes the transfer activity in Russian' do
    online(teammate)

    I18n.with_locale(:ru) { transfer }

    expect(conversation.messages.activity.last.content).to eq(
      "Чат переведён на оператора #{teammate.name} с оператора #{current_agent.name}"
    )
  end

  it 'does not transfer to an online agent from another team' do
    online(outsider)

    result = transfer

    expect(result[:success]).to be(false)
    expect(conversation.reload.assignee).to eq(current_agent)
    expect(conversation.messages.activity.last.content).to eq(
      'No available agent in this team to transfer the conversation'
    )
  end

  it 'skips a teammate who is over the active chat limit' do
    account.update!(active_chat_limit_enabled: true, active_chat_limit_value: 1)
    create(:conversation, account: account, inbox: inbox, assignee: teammate, team: team)
    online(teammate, outsider)

    result = transfer

    expect(result[:success]).to be(false)
    expect(conversation.reload.assignee).to eq(current_agent)
  end

  it 'removes a queued conversation from the queue when a teammate takes it' do
    conversation.update_columns(status: Conversation.statuses[:queued]) # rubocop:disable Rails/SkipsModelValidations
    ConversationQueue.create!(
      account: account,
      inbox: inbox,
      conversation: conversation,
      status: :waiting,
      queued_at: Time.current
    )
    online(teammate)

    transfer

    expect(conversation.reload).to be_open
    expect(conversation.assignee).to eq(teammate)
    expect(ConversationQueue.find_by(conversation_id: conversation.id).status).to eq('assigned')
  end

  it 'transfers inside the inbox when the conversation has no team' do
    conversation.update!(team: nil)
    online(outsider)

    result = transfer

    expect(result[:success]).to be(true)
    expect(conversation.reload.assignee).to eq(outsider)
  end
end
