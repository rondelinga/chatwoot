require 'rails_helper'

RSpec.describe ChatRouting::ResolveService do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team) { create(:team, account: account) }
  let(:team_bot) { create(:agent_bot, account: account, name: 'Team Bot') }
  let(:config_bot) { create(:agent_bot, account: account, name: 'Config Bot') }

  before do
    InboxTeam.create!(inbox: inbox, team: team, is_default: true, agent_bot: nil)
  end

  def resolve(attrs = {})
    described_class.new(
      inbox_id: inbox.id,
      account_id: account.id,
      contact_custom_attributes: attrs
    ).perform
  end

  it 'uses the team bot when the inbox team link has one' do
    InboxTeam.find_by!(inbox: inbox, team: team).update!(agent_bot: team_bot)
    create(:agent_bot_inbox, inbox: inbox, agent_bot: config_bot)

    result = resolve

    expect(result.team_id).to eq(team.id)
    expect(result.bot_id).to eq(team_bot.id)
  end

  it 'falls back to the inbox Bot Configuration when the team has no bot' do
    create(:agent_bot_inbox, inbox: inbox, agent_bot: config_bot)

    result = resolve

    expect(result.team_id).to eq(team.id)
    expect(result.bot_id).to eq(config_bot.id)
  end

  it 'does not use an inactive inbox Bot Configuration' do
    create(:agent_bot_inbox, inbox: inbox, agent_bot: config_bot, status: :inactive)

    result = resolve

    expect(result.team_id).to eq(team.id)
    expect(result.bot_id).to be_nil
  end

  it 'keeps the team bot when routing matches a typed inbox team' do
    routing_type = RoutingType.create!(
      account: account,
      name: 'VIP',
      attribute_key: 'vip',
      attribute_value: 'true'
    )
    vip_team = create(:team, account: account)
    InboxTeam.create!(
      inbox: inbox,
      team: vip_team,
      routing_type: routing_type,
      agent_bot: team_bot,
      is_default: false
    )
    create(:agent_bot_inbox, inbox: inbox, agent_bot: config_bot)

    result = resolve('vip' => true)

    expect(result.team_id).to eq(vip_team.id)
    expect(result.bot_id).to eq(team_bot.id)
    expect(result.matched_by_default).to be(false)
  end
end
