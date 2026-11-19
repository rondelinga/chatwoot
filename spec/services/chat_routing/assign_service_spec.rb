require 'rails_helper'

RSpec.describe ChatRouting::AssignService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:config_bot) { create(:agent_bot, account: account) }
  let(:contact) { create(:contact, account: account) }
  let(:contact_inbox) { create(:contact_inbox, contact: contact, inbox: inbox) }

  before do
    InboxTeam.create!(inbox: inbox, team: team, is_default: true)
    create(:agent_bot_inbox, inbox: inbox, agent_bot: config_bot)
  end

  it 'assigns the inbox configuration bot and marks the conversation pending' do
    conversation = build(
      :conversation,
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox
    )

    described_class.new(conversation: conversation).apply

    expect(conversation.team_id).to eq(team.id)
    expect(conversation.ai_assignee).to eq(config_bot)
    expect(conversation.ai_assignee_type).to eq('AgentBot')
    expect(conversation.assignee_agent_bot_id).to eq(config_bot.id)
    expect(conversation.pending_for_bot?).to be(true)
  end

  it 'prefers the team bot over the inbox configuration bot' do
    team_bot = create(:agent_bot, account: account, name: 'Team Bot')
    InboxTeam.find_by!(inbox: inbox, team: team).update!(agent_bot: team_bot)

    conversation = build(
      :conversation,
      account: account,
      inbox: inbox,
      contact: contact,
      contact_inbox: contact_inbox
    )

    described_class.new(conversation: conversation).apply

    expect(conversation.ai_assignee).to eq(team_bot)
    expect(conversation.assignee_agent_bot_id).to eq(team_bot.id)
  end
end
