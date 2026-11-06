# Opens and closes agent participation intervals and records their duration.
module ConversationParticipantSessions
  extend ActiveSupport::Concern

  included do
    before_update :close_previous_agent_on_reassign
    before_update :close_agents_on_resolve
    after_update :create_participant_for_new_agent
  end

  def operator_replied_after?(operator_id:, from_time:, to_time:)
    messages.where(sender_type: 'User', sender_id: operator_id, message_type: :outgoing)
            .exists?(['created_at > ? AND created_at < ?', from_time, to_time])
  end

  private

  def track_agent_chat_duration(participant)
    return if participant.created_at.nil? || participant.left_at.nil?

    duration = participant.left_at - participant.created_at
    return if duration <= 0

    reporting_events.create!(
      account_id: account_id,
      user_id: participant.user_id,
      name: :agent_chat_duration,
      value: duration.to_i
    )
  end

  def close_previous_agent_on_reassign
    return unless will_save_change_to_assignee_id?

    prev_id, new_id = assignee_id_change
    return if prev_id.nil? || prev_id == new_id

    participant = ConversationParticipant.find_by(conversation_id: id, user_id: prev_id, left_at: nil)
    return unless participant

    participant.update!(left_at: Time.current)
    track_agent_chat_duration(participant)
  end

  def create_participant_for_new_agent
    return unless saved_change_to_assignee_id?
    return if assignee_id.nil?

    participant = ConversationParticipant.find_or_initialize_by(conversation_id: id, user_id: assignee_id)
    now = Time.current

    if participant.persisted?
      participant.update!(left_at: nil, created_at: now)
    else
      participant.created_at = now
      participant.save!
    end
  end

  def close_agents_on_resolve
    return unless will_save_change_to_status?
    return unless status == 'resolved'

    ConversationParticipant.where(conversation_id: id, left_at: nil).find_each do |participant|
      participant.update!(left_at: Time.current)
      track_agent_chat_duration(participant)
    end
  end
end
