class Api::V1::Accounts::InboxTeamAssignmentsController < Api::V1::Accounts::BaseController
  def create
    authorize Current.account.inboxes.new, :update?
    Inboxes::BulkTeamAssignmentService.new(
      account: Current.account,
      sets: assignment_sets
    ).perform
    head :ok
  rescue Inboxes::BulkTeamAssignmentService::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def assignment_sets
    Array(params[:sets]).map { |set| assignment_set(set) }
  end

  def assignment_set(set)
    set.permit(:mode, inbox_ids: [], team_configs: [:team_id, :is_default]).to_h.deep_symbolize_keys
  end
end
