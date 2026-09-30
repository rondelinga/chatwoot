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
