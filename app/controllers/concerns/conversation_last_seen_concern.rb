module ConversationLastSeenConcern
  extend ActiveSupport::Concern

  private

  def update_last_seen_on_conversation(last_seen_at, update_assignee)
    updates = { agent_last_seen_at: last_seen_at }
    updates[:assignee_last_seen_at] = last_seen_at if update_assignee.present?
    @conversation.update_columns(updates) # rubocop:disable Rails/SkipsModelValidations -- last_seen writes skip callbacks by design
    ::Conversations::UnreadCounts::Notifier.new(@conversation).perform
    ::Conversations::UnreadCounts::FilteredCountInvalidator.new(Current.account).conversation_changed!
  end

  def should_update_last_seen?
    agent_needs_update = @conversation.agent_last_seen_at.blank? || @conversation.agent_last_seen_at < 1.hour.ago
    return agent_needs_update unless assignee?

    assignee_needs_update = @conversation.assignee_last_seen_at.blank? || @conversation.assignee_last_seen_at < 1.hour.ago
    agent_needs_update || assignee_needs_update
  end

  def assignee?
    @conversation.assignee_id? && Current.user == @conversation.assignee
  end
end
