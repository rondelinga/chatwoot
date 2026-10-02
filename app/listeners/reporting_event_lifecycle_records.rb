module ReportingEventLifecycleRecords
  private

  def create_conversation_resolved_events(conversation, start_time, end_time, time_to_resolve)
    user_ids = conversation.conversation_participants.where.not(user_id: nil).distinct.pluck(:user_id)

    if user_ids.empty?
      persist_reporting_event(conversation, name: 'conversation_resolved', value: time_to_resolve,
                                            start_time: start_time, end_time: end_time)
    else
      user_ids.each do |user_id|
        persist_reporting_event(conversation, name: 'conversation_resolved', value: time_to_resolve,
                                              start_time: start_time, end_time: end_time, user_id: user_id)
      end
    end

    create_bot_resolved_event(conversation, start_time, end_time, time_to_resolve)
  end

  def create_conversation_opened_event(conversation, time_since_resolved, business_hours_value, start_time)
    persist_reporting_event(
      conversation,
      name: 'conversation_opened',
      value: time_since_resolved,
      start_time: start_time,
      end_time: conversation.updated_at,
      user_id: conversation.assignee_id,
      value_in_business_hours: business_hours_value,
      rollup: false
    )
  end

  def create_reply_time_event(conversation, operator_id, client_message, message, waiting_time)
    persist_reporting_event(
      conversation,
      name: 'reply_time',
      value: waiting_time,
      start_time: client_message.created_at,
      end_time: message.created_at,
      user_id: operator_id
    )
  end

  def handle_bot_first_response(conversation, message)
    persist_timed_event(
      conversation,
      message,
      name: 'bot_first_response',
      start_time: conversation.created_at,
      agent_bot_id: message.sender_id,
      rollup: false
    )
  end

  def record_conversation_opened(conversation, event_end_time)
    last_resolved_event = ReportingEvent.where(conversation_id: conversation.id, name: 'conversation_resolved')
                                        .order(event_end_time: :desc).first
    if last_resolved_event
      time_since_resolved = event_end_time.to_i - last_resolved_event.event_end_time.to_i
      hours_value = business_hours(conversation.inbox, last_resolved_event.event_end_time, event_end_time)
      start_time = last_resolved_event.event_end_time
    else
      time_since_resolved = 0
      hours_value = 0
      start_time = conversation.created_at
    end

    create_conversation_opened_event(conversation, time_since_resolved, hours_value, start_time)
  end

  def persist_bot_handoff(conversation, event_end_time)
    return if ReportingEvent.find_by(conversation_id: conversation.id, name: 'conversation_bot_handoff').present?

    persist_reporting_event(
      conversation,
      name: 'conversation_bot_handoff',
      value: event_end_time.to_i - conversation.created_at.to_i,
      start_time: conversation.created_at,
      end_time: event_end_time,
      user_id: conversation.assignee_id
    )
  end
end
