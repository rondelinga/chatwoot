class Api::V1::Accounts::InboxMembersController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox

  def show
    authorize @inbox, :show?
    fetch_updated_agents
  end

  def create
    authorize @inbox, :create?
    return render_direct_assignment_error if params[:user_ids].present?

    ActiveRecord::Base.transaction do
      @inbox.update_teams(params[:team_ids]) if params[:team_ids].present?
    end
    fetch_updated_agents
  end

  def update
    authorize @inbox, :update?
    return render_direct_assignment_error if params[:user_ids].present?

    ActiveRecord::Base.transaction do
      @inbox.update_teams(params[:team_ids]) if params[:team_ids].present?
    end
    fetch_updated_agents
  end

  def destroy
    authorize @inbox, :destroy?
    return render_direct_assignment_error if params[:user_ids].present?

    head :ok
  end

  private

  def render_direct_assignment_error
    render json: { error: 'Direct agent assignment is disabled. Assign teams to the inbox instead.' },
           status: :unprocessable_entity
  end

  def fetch_updated_agents
    @agents = Current.account.users.where(id: @inbox.members.select(:user_id))
  end

  def fetch_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
  end
end
