class Api::V1::Accounts::TeamMembersController < Api::V1::Accounts::BaseController
  before_action :fetch_team
  before_action :check_authorization
  before_action :validate_member_id_params, only: [:create, :update, :destroy]

  def index
    @team_members = @team.team_members.includes(:user)
  end

  def create
    ActiveRecord::Base.transaction do
      @team_members = @team.sync_members(
        primary_user_ids: primary_user_ids,
        backup_user_ids: backup_user_ids
      )
    end
  end

  def update
    ActiveRecord::Base.transaction do
      @team_members = @team.sync_members(
        primary_user_ids: primary_user_ids,
        backup_user_ids: backup_user_ids
      )
    end
    render action: 'create'
  end

  def destroy
    ActiveRecord::Base.transaction do
      @team.remove_members(params[:user_ids])
    end
    head :ok
  end

  private

  def primary_user_ids
    params[:primary_user_ids] || []
  end

  def backup_user_ids
    params[:backup_user_ids] || []
  end

  def member_user_ids
    (primary_user_ids + backup_user_ids).map(&:to_i)
  end

  def fetch_team
    @team = Current.account.teams.find(params[:team_id])
  end

  def validate_member_id_params
    if overlapping_member_ids.present?
      render json: { error: 'Agent cannot be both primary and backup' }, status: :unprocessable_entity
      return
    end

    invalid_ids = member_user_ids - @team.account.user_ids

    render json: { error: 'Invalid User IDs' }, status: :unauthorized and return if invalid_ids.present?
  end

  def overlapping_member_ids
    primary_user_ids.map(&:to_i) & backup_user_ids.map(&:to_i)
  end
end
