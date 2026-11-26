require 'rails_helper'

describe Inboxes::BulkTeamAssignmentService do
  let(:account) { create(:account) }
  let(:regular) { create(:team, account: account, name: 'Regular') }
  let(:privip) { create(:team, account: account, name: 'PriVip') }
  let(:vip) { create(:team, account: account, name: 'VIP') }
  let(:arkada) { create(:inbox, account: account, name: 'Arkada Regular') }
  let(:cat) { create(:inbox, account: account, name: 'Cat Regular') }

  it 'adds the selected teams and marks one as the default' do
    InboxTeam.create!(inbox: arkada, team: vip, is_default: true)

    described_class.new(
      account: account,
      sets: [
        {
          mode: 'add',
          inbox_ids: [arkada.id, cat.id],
          team_configs: [
            { team_id: regular.id, is_default: true },
            { team_id: privip.id, is_default: false },
            { team_id: vip.id, is_default: false }
          ]
        }
      ]
    ).perform

    expect(arkada.inbox_teams.pluck(:team_id)).to contain_exactly(regular.id, privip.id, vip.id)
    expect(arkada.inbox_teams.find_by!(team_id: regular.id).is_default).to be(true)
    expect(arkada.inbox_teams.where(is_default: true).count).to eq(1)
    expect(cat.inbox_teams.find_by!(team_id: regular.id).is_default).to be(true)
  end

  it 'replaces previously assigned teams' do
    InboxTeam.create!(inbox: arkada, team: vip, is_default: true)

    described_class.new(
      account: account,
      sets: [
        {
          mode: 'replace',
          inbox_ids: [arkada.id],
          team_configs: [
            { team_id: regular.id, is_default: true },
            { team_id: privip.id, is_default: false }
          ]
        }
      ]
    ).perform

    expect(arkada.inbox_teams.pluck(:team_id)).to contain_exactly(regular.id, privip.id)
    expect(arkada.inbox_teams.find_by!(team_id: regular.id).is_default).to be(true)
  end

  it 'rejects a set without a default team' do
    expect do
      described_class.new(
        account: account,
        sets: [
          {
            mode: 'add',
            inbox_ids: [arkada.id],
            team_configs: [{ team_id: regular.id, is_default: false }]
          }
        ]
      ).perform
    end.to raise_error(described_class::Error, 'Choose one default team')
  end
end
