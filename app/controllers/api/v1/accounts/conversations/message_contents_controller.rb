class Api::V1::Accounts::Conversations::MessageContentsController < Api::V1::Accounts::Conversations::BaseController
  def update
    @message = Messages::EditContentService.new(
      message: message,
      content: params[:content].to_s
    ).perform
    render 'api/v1/accounts/conversations/messages/update'
  rescue Messages::EditContentService::Error => e
    render_could_not_create_error(e.message)
  end

  private

  def message
    @message ||= @conversation.messages.find(params[:id])
  end
end
