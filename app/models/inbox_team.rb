# == Schema Information
#
# Table name: inbox_teams
#
#  id              :bigint           not null, primary key
#  is_default      :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  agent_bot_id    :bigint
#  inbox_id        :bigint           not null
#  routing_type_id :bigint
#  team_id         :bigint           not null
#
# Indexes
#
#  index_inbox_teams_on_agent_bot_id          (agent_bot_id)
#  index_inbox_teams_on_inbox_id              (inbox_id)
#  index_inbox_teams_on_inbox_id_and_team_id  (inbox_id,team_id) UNIQUE
#  index_inbox_teams_on_routing_type_id       (routing_type_id)
#  index_inbox_teams_on_team_id               (team_id)
#
# Foreign Keys
#
#  fk_rails_...  (agent_bot_id => agent_bots.id)
#  fk_rails_...  (inbox_id => inboxes.id)
#  fk_rails_...  (routing_type_id => routing_types.id)
#  fk_rails_...  (team_id => teams.id)
#
class InboxTeam < ApplicationRecord
  belongs_to :inbox
  belongs_to :team
  belongs_to :routing_type, optional: true
  belongs_to :agent_bot, optional: true

  validates :team_id, uniqueness: { scope: :inbox_id }
  validate :team_belongs_to_same_account
  validate :single_default_per_inbox, if: :is_default?

  after_commit :sync_inbox_members, on: [:create, :update, :destroy]

  private

  def single_default_per_inbox
    exists = InboxTeam.where(inbox_id: inbox_id, is_default: true).where.not(id: id).exists?
    errors.add(:base, 'Inbox already has a default team') if exists
  end

  def team_belongs_to_same_account
    return if team.blank? || inbox.blank?
    return if team.account_id == inbox.account_id

    errors.add(:team_id, 'must belong to the same account as the inbox')
  end

  def sync_inbox_members
    Inboxes::MembersSyncService.new(inbox: inbox).perform
  end
end
