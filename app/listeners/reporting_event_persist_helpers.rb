module ReportingEventPersistHelpers
  private

  def persist_timed_event(conversation, message, **attrs)
    start_time = attrs[:start_time]
    value = message.created_at.to_i - start_time.to_i
    return if value <= 0

    persist_reporting_event(
      conversation,
      name: attrs[:name],
      value: value,
      start_time: start_time,
      end_time: message.created_at,
      rollup: attrs.fetch(:rollup, true),
      bang: attrs.fetch(:bang, true),
      **attrs.slice(:user_id, :agent_bot_id)
    )
  end

  def persist_reporting_event(conversation, **extras)
    rollup = extras.key?(:rollup) ? extras.delete(:rollup) : true
    bang = extras.key?(:bang) ? extras.delete(:bang) : true
    reporting_event = build_reporting_event(conversation, extras)
    bang ? reporting_event.save! : reporting_event.save
    safe_rollup(reporting_event) if rollup
  end

  def build_reporting_event(conversation, extras)
    start_time = extras[:start_time]
    end_time = extras[:end_time]
    hours_value = extras.delete(:value_in_business_hours) { business_hours(conversation.inbox, start_time, end_time) }

    attrs = {
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      conversation_id: conversation.id,
      value_in_business_hours: hours_value,
      event_start_time: start_time,
      event_end_time: end_time,
      name: extras[:name],
      value: extras[:value]
    }
    attrs[:user_id] = extras[:user_id] if extras.key?(:user_id)
    attrs[:agent_bot_id] = extras[:agent_bot_id] if extras.key?(:agent_bot_id)
    ReportingEvent.new(attrs)
  end

  def participant_user_ids(conversation)
    user_ids = conversation.conversation_participants.where.not(user_id: nil).distinct.pluck(:user_id)
    user_ids.presence || [nil]
  end

  def last_incoming_before(conversation, message)
    conversation.messages.incoming.where('created_at < ?', message.created_at).last
  end

  def bot_already_replied_between?(conversation, client_message, message)
    conversation.messages.where(message_type: :outgoing, sender_type: ['AgentBot', 'Captain::Assistant'])
                .where('created_at > ?', client_message.created_at)
                .exists?(['created_at < ?', message.created_at])
  end
end
