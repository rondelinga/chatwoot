class ReportingEventListener < BaseListener
  include ReportingEventHelper
  include ReportingEventPersistHelpers
  include ReportingEventRecordBuilders
  include ReportingEventLifecycleRecords

  def conversation_resolved(event)
    conversation = extract_conversation_and_account(event)[0]
    return if conversation.resolved_at.blank?

    start_time = conversation.created_at
    end_time = conversation.resolved_at
    time_to_resolve = end_time - start_time
    return if time_to_resolve <= 0

    create_conversation_resolved_events(conversation, start_time, end_time, time_to_resolve)
    record_resolution_without_bot(conversation, start_time, end_time, time_to_resolve)
  end

  def first_reply_created(event)
    message = extract_message_and_account(event)[0]
    conversation = message.conversation

    return unless message.message_type == 'outgoing'
    return unless message.sender_type == 'User'

    participant = ConversationParticipant.find_by(
      conversation_id: conversation.id,
      user_id: message.sender_id,
      left_at: nil
    )
    return if participant.blank?
    return if participant.created_at.blank?

    create_first_response_event(conversation, message, participant)

    create_first_response_from_open_event(conversation, message)
  end

  def reply_created(event)
    message = extract_message_and_account(event)[0]
    return unless message.sender_type == 'User'

    conversation = message.conversation
    operator_id = message.sender_id

    participant = ConversationParticipant.find_by(conversation_id: conversation.id, user_id: operator_id, left_at: nil)
    return if participant&.created_at.blank?

    client_message = last_client_message(conversation, participant, message)
    return unless client_message

    waiting_time = message.created_at.to_i - client_message.created_at.to_i
    return if waiting_time <= 0

    create_reply_time_event(conversation, operator_id, client_message, message, waiting_time)
  end

  def conversation_bot_handoff(event)
    conversation = extract_conversation_and_account(event)[0]
    persist_bot_handoff(conversation, event.timestamp)
  end

  def conversation_opened(event)
    conversation = extract_conversation_and_account(event)[0]
    record_conversation_opened(conversation, event.timestamp)
  end

  def message_created(event)
    message = extract_message_and_account(event)[0]
    conversation = message.conversation

    return unless bot_message_applicable?(message)

    # Bot first response
    handle_bot_first_response(conversation, message) if bot_first_response_applicable?(conversation, message)

    # Bot reply time
    handle_bot_reply_time(conversation, message)
  end

  private

  def resolution_without_bot_start_time(conversation, opened_time, log_prefix)
    unless conversation.inbox.active_bot?
      Rails.logger.info("#{log_prefix} | has_bot=false | without_bot_start_time=conversation_start=#{opened_time.iso8601}")
      return opened_time
    end

    operator_first_message_at = first_operator_message_at(conversation)
    if operator_first_message_at
      Rails.logger.info(
        "#{log_prefix} | has_bot=true | source=first_operator_message | " \
        "without_bot_start_time=#{operator_first_message_at.iso8601}"
      )
      return operator_first_message_at
    end

    Rails.logger.warn(
      "#{log_prefix} | has_bot=true | WITHOUT_BOT_EVENT_SKIPPED | " \
      'reason=no_operator_ever_replied | fallback=no_event_created'
    )
    nil
  end

  def first_operator_message_at(conversation)
    conversation.messages
                .where(message_type: :outgoing, sender_type: 'User')
                .minimum(:created_at)
  end

  def last_client_message(conversation, participant, message)
    client_message = conversation.messages.incoming.where('created_at >= ?', participant.created_at)
                                 .where('created_at < ?', message.created_at).last
    return unless client_message

    operator_replied_between = conversation.messages.where(message_type: :outgoing, sender_type: 'User', sender_id: message.sender_id)
                                           .where('created_at > ?', client_message.created_at)
                                           .exists?(['created_at < ?', message.created_at])

    return if operator_replied_between

    client_message
  end

  def safe_rollup(reporting_event)
    # Rollups are derived from the raw reporting event. If a transient rollup write
    # failure bubbles out here, Sidekiq retries the dispatcher job and can insert the
    # same raw event again. That can temporarily under-report rollups, but the source
    # event is preserved and rollup data can be rebuilt or re-applied later.
    ReportingEvents::RollupService.perform(reporting_event)
  rescue StandardError => e
    ChatwootExceptionTracker.new(e, account: reporting_event.account).capture_exception
  end

  def bot_message_applicable?(message)
    return false unless message.message_type == 'outgoing'
    return false unless message.sender_type.in?(['AgentBot', 'Captain::Assistant'])

    true
  end

  def bot_first_response_applicable?(conversation, message)
    # Check if this is the first bot response in the conversation
    return false if ReportingEvent.exists?(
      conversation_id: conversation.id,
      name: 'bot_first_response'
    )

    # Ensure there's no prior bot message
    prior_bot_message = conversation.messages
                                    .where(message_type: :outgoing)
                                    .where(sender_type: ['AgentBot', 'Captain::Assistant'])
                                    .exists?(['created_at < ?', message.created_at])

    !prior_bot_message
  end
end
