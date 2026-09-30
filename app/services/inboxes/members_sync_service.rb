class Inboxes::MembersSyncService
  pattr_initialize [:inbox!]

  def perform
    desired_user_ids = desired_member_ids
    current_user_ids = inbox.inbox_members.pluck(:user_id)

    to_add = desired_user_ids - current_user_ids
    to_remove = current_user_ids - desired_user_ids

    inbox.add_members(to_add) if to_add.any?
    inbox.remove_members(to_remove) if to_remove.any?
  end

  private

  def desired_member_ids
    TeamMember
      .joins(team: :inbox_teams)
      .where(inbox_teams: { inbox_id: inbox.id })
      .distinct
      .pluck(:user_id)
  end
end
