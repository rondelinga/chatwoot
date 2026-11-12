require 'rails_helper'

RSpec.describe ConversationQueue, type: :model do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:team_a) { create(:team, account: account) }
  let(:team_b) { create(:team, account: account) }

  def enqueue(team)
    conversation = create(:conversation, account: account, inbox: inbox, team: team, assignee: nil)
    described_class.create!(
      account: account,
      inbox: inbox,
      conversation: conversation,
      status: :waiting,
      queued_at: Time.current
    )
  end

  it 'numbers positions inside a team, independently of other teams' do
    first_a = enqueue(team_a)
    first_b = enqueue(team_b)
    second_a = enqueue(team_a)

    expect(first_a.position).to eq(1)
    expect(first_b.position).to eq(1)
    expect(second_a.position).to eq(2)
  end
end
