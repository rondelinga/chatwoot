class Api::V1::Accounts::Contacts::OutboundMessagesController < Api::V1::Accounts::Contacts::BaseController
  before_action :authorize_outbound_message
  before_action :set_inbox, only: :create

  def create
    authorize @inbox, :show?

    result = Contacts::OutboundMessageService.new(
      account: Current.account,
      user: Current.user,
      contact: @contact,
      inbox: @inbox,
      content: params[:content]
    ).perform

    @conversation = result[:conversation]
    @message = result[:message]
  rescue Contacts::OutboundMessageService::Error => e
    render_could_not_create_error(e.message)
  end

  def inboxes
    @outbound_inboxes = Contacts::OutboundMessageService.inboxes_for(
      contact: @contact,
      user: Current.user
    )
  end

  private

  def authorize_outbound_message
    authorize @contact, :outbound_message?
  end

  def set_inbox
    @inbox = Current.account.inboxes.find(params.require(:inbox_id))
  end
end
