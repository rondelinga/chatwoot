class Api::V1::Accounts::Conversations::ForceTransfersController < Api::V1::Accounts::Conversations::BaseController
  def create
    result = ChatQueue::ForceTransferService.new(
      conversation: @conversation,
      current_user: Current.user
    ).perform

    if result[:success]
      render json: {
        success: true,
        agent: agent_payload(result[:agent]),
        message: result[:message]
      }
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end

  private

  def agent_payload(agent)
    {
      id: agent.id,
      name: agent.name,
      email: agent.email,
      avatar_url: agent.avatar_url
    }
  end
end
