class Api::V1::Accounts::InboxPriorityMembersController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox

  def update
    authorize @inbox, :update?
    apply_urgent_flags(urgent_member_ids)
    head :ok
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end

  def urgent_member_ids
    selected_ids = Array(params[:user_ids]).map(&:to_i)
    selected_ids & @inbox.inbox_members.pluck(:user_id)
  end

  def apply_urgent_flags(urgent_ids)
    @inbox.inbox_members.find_each do |member|
      urgent = urgent_ids.include?(member.user_id)
      member.update!(urgent: urgent) if member.urgent != urgent
    end
  end
end
