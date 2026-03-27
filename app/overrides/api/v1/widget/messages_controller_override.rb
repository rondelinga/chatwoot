module Overrides
  module Api
    module V1
      module Widget
        module MessagesControllerOverride
          def update
            if @message.content_type == 'input_email'
              @message.update!(submitted_email: contact_email)
              ContactIdentifyAction.new(
                contact: @contact,
                params: { email: contact_email, name: contact_name },
                retain_original_contact_name: true,
                inbox_id: @web_widget.inbox.id
              ).perform
            else
              @message.update!(message_update_params[:message])
            end
          rescue StandardError => e
            render json: { error: @contact.errors, message: e.message }.to_json, status: :internal_server_error
          end

          private

          def send_conversation_closed_message
            last_message = conversation.messages.where(message_type: :template).last
            return if last_message&.content == I18n.t('conversations.closed_message')

            conversation.messages.create!(
              account_id: conversation.account_id,
              inbox_id: conversation.inbox_id,
              message_type: :template,
              content: I18n.t('conversations.closed_message')
            )
          rescue StandardError => e
            Rails.logger.error "Failed to send closed message: #{e.message}"
          end
        end
      end
    end
  end
end

Api::V1::Widget::MessagesController.prepend(Overrides::Api::V1::Widget::MessagesControllerOverride)

Api::V1::Widget::MessagesController.class_eval do
  before_action :check_conversation_status, only: [:create]

  def check_conversation_status
    return if conversation.nil?
    return unless conversation.resolved?
    return if @web_widget.inbox.allow_messages_after_resolved

    send_conversation_closed_message

    render json: {
      error: 'conversation_closed',
      message: I18n.t('conversations.closed_message')
    }, status: :forbidden
  end
end
