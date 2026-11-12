module ConversationChatRouting
  extend ActiveSupport::Concern

  included do
    before_validation :apply_chat_routing, on: :create
    after_create :create_chat_routing_activity_messages
  end

  private

  def apply_chat_routing
    @chat_routing_result = ChatRouting::AssignService.new(conversation: self).apply
  end

  def create_chat_routing_activity_messages
    ChatRouting::AssignService.new(conversation: self).create_activity_messages(@chat_routing_result)
  end
end
