class Api::V1::Accounts::InboxTeamsController < Api::V1::Accounts::BaseController
  before_action :fetch_inbox

  def show
    @teams = @inbox.teams
    @agents = @inbox.members.uniq
  end

  def update
    ActiveRecord::Base.transaction { sync_inbox_teams }
    @teams = @inbox.teams.reload
    @agents = @inbox.members.reload.uniq
    render :show
  end

  private

  def fetch_inbox
    @inbox = Current.account.inboxes.find(permitted_params[:inbox_id])
  end

  def sync_inbox_teams
    configs = permitted_params[:team_configs] || []
    incoming_ids = configs.map { |c| c[:team_id].to_i }

    @inbox.inbox_teams.where.not(team_id: incoming_ids).destroy_all

    configs.each do |config|
      inbox_team = @inbox.inbox_teams.find_or_initialize_by(team_id: config[:team_id])
      inbox_team.update!(
        is_default: false,
        routing_type_id: config[:routing_type_id].presence,
        agent_bot_id: config[:agent_bot_id].presence
      )
    end

    default_config = configs.find { |c| ActiveModel::Type::Boolean.new.cast(c[:is_default]) }
    return if default_config.blank?

    @inbox.inbox_teams.find_by!(team_id: default_config[:team_id]).update!(is_default: true)
  end

  def permitted_params
    params.permit(
      :inbox_id,
      team_configs: [:team_id, :is_default, :routing_type_id, :agent_bot_id]
    )
  end
end
