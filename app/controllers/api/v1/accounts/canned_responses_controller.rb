class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_canned_response, only: [:update, :destroy]

  def index
    render json: canned_responses, include: [:canned_response_scopes]
  end

  def create
    result = save_canned_response
    return render_canned_response_error(result.error) if result.error

    render json: result.canned_response.as_json(include: :canned_response_scopes)
  end

  def update
    result = save_canned_response(@canned_response)
    return render_canned_response_error(result.error) if result.error

    render json: result.canned_response.as_json(include: :canned_response_scopes)
  end

  def destroy
    CannedResponses::DestroyService.new(canned_response: @canned_response, user: current_user).perform
    head :ok
  end

  private

  def fetch_canned_response
    @canned_response = Current.account.canned_responses.find(params[:id])
  end

  def canned_response_params
    params.require(:canned_response).permit(:short_code, :content, :visibility)
  end

  def scope_ids
    {
      user_ids: params[:user_ids],
      team_ids: params[:team_ids],
      inbox_ids: params[:inbox_ids]
    }
  end

  def canned_responses
    Current.account.canned_responses.listed_for(
      current_user,
      include_all: params[:all],
      inbox_id: params[:inbox_id],
      search: params[:search]
    )
  end

  def save_canned_response(canned_response = nil)
    CannedResponses::SaveService.new(
      account: Current.account,
      user: current_user,
      canned_response: canned_response,
      attributes: canned_response_params,
      scope_ids: scope_ids
    ).perform
  end

  def render_canned_response_error(error)
    render json: { error: error }, status: :unprocessable_entity
  end
end
