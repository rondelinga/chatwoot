module ReportingEventRecordBuilders
  private

  def record_resolution_without_bot(conversation, start_time, end_time, time_to_resolve)
    log_prefix = "[ResolutionMetric] conv_id=#{conversation.id} inbox_id=#{conversation.inbox_id}"
    without_bot_start_time = resolution_without_bot_start_time(conversation, start_time, log_prefix)
    return if without_bot_start_time.nil?

    log_resolution_without_bot(log_prefix, without_bot_start_time, start_time, end_time, time_to_resolve)
    create_resolution_without_bot_events(conversation, without_bot_start_time)
  end

  def log_resolution_without_bot(log_prefix, without_bot_start_time, start_time, end_time, time_to_resolve)
    Rails.logger.info(
      "#{log_prefix} | creating resolution_time_without_bot | " \
      "without_bot_start_time=#{without_bot_start_time.iso8601} | resolved_at=#{end_time.iso8601} | " \
      "time_without_bot=#{(end_time - without_bot_start_time).to_i}s | " \
      "total_resolution_time=#{time_to_resolve.to_i}s | bot_time=#{(without_bot_start_time - start_time).to_i}s"
    )
  end

  def create_resolution_without_bot_events(conversation, opened_time)
    resolution_time = conversation.resolved_at.to_i - opened_time.to_i
    return if resolution_time <= 0

    participant_user_ids(conversation).each do |user_id|
      persist_reporting_event(
        conversation,
        name: 'resolution_time_without_bot',
        value: resolution_time,
        start_time: opened_time,
        end_time: conversation.resolved_at,
        user_id: user_id
      )
    end
  end

  def create_bot_resolved_event(conversation, start_time, end_time, time_to_resolve)
    bot_id = bot_resolved_sender_id(conversation)
    return if bot_id.blank?

    persist_reporting_event(conversation, name: 'conversation_bot_resolved', value: time_to_resolve,
                                          start_time: start_time, end_time: end_time, agent_bot_id: bot_id)
  end

  def create_first_response_event(conversation, message, participant)
    assignment_time = participant.created_at
    return if first_response_already_recorded?(conversation, message, assignment_time)

    persist_timed_event(conversation, message, name: 'first_response', start_time: assignment_time, user_id: message.sender_id)
  end

  def create_first_response_from_open_event(conversation, message)
    start_time = first_response_from_open_start_time(conversation, message)
    return if ReportingEvent.exists?(
      conversation_id: conversation.id, user_id: message.sender_id, name: 'first_response_from_open', event_start_time: start_time
    )

    persist_timed_event(
      conversation,
      message,
      name: 'first_response_from_open',
      start_time: start_time,
      user_id: message.sender_id,
      rollup: false,
      bang: false
    )
  end

  def handle_bot_reply_time(conversation, message)
    client_message = last_incoming_before(conversation, message)
    return unless client_message
    return if bot_already_replied_between?(conversation, client_message, message)

    persist_timed_event(
      conversation,
      message,
      name: 'bot_reply_time',
      start_time: client_message.created_at,
      agent_bot_id: message.sender_id,
      rollup: false
    )
  end

  def bot_resolved_sender_id(conversation)
    return unless conversation.inbox.active_bot?
    return if conversation.messages.exists?(message_type: :outgoing, sender_type: 'User')
    return if ReportingEvent.exists?(conversation_id: conversation.id, name: 'conversation_bot_resolved')

    conversation.messages.where(message_type: :outgoing, sender_type: ['AgentBot', 'Captain::Assistant']).pick(:sender_id)
  end

  def first_response_already_recorded?(conversation, message, assignment_time)
    ReportingEvent.exists?(
      conversation_id: conversation.id, user_id: message.sender_id, name: 'first_response', event_start_time: assignment_time
    )
  end

  def first_response_from_open_start_time(conversation, message)
    ReportingEvent.where(conversation_id: conversation.id, name: 'conversation_opened')
                  .where('event_end_time <= ?', message.created_at)
                  .order(event_end_time: :desc)
                  .first&.event_end_time || conversation.created_at
  end
end
