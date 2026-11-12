class ChatQueue::Queue::FetchService
  pattr_initialize [:account!]

  def fetch_queue_entry
    next_assignable_entry
  end

  def oldest_assignable_head(skipped_lane_keys)
    lane_heads
      .reject { |entry| skipped_lane_keys.include?(lane_key(entry)) }
      .min_by { |entry| [entry.queued_at, entry.id] }
  end

  def lane_key(entry)
    conversation = entry.conversation
    return [:team, conversation.team_id] if conversation.team_id.present?

    [:inbox, conversation.inbox_id]
  end

  def fetch_specific_entry(conv_id)
    entry = ConversationQueue.find_by(conversation_id: conv_id, status: :waiting)

    unless entry
      Rails.logger.info("[QUEUE][fetch_specific][conv=#{conv_id}] No waiting entry found")
      return nil
    end

    return reconcile_inconsistent_entry(entry) if inconsistent_queue_entry?(entry)

    entry
  end

  def next_in_queue
    Rails.logger.info("[QUEUE][next] Fetching next conversation for account #{account.id}")

    next_assignable_entry&.conversation
  end

  def queue_size
    size = ConversationQueue.for_account(account.id)
                            .waiting
                            .joins(:conversation)
                            .where(conversations: { assignee_id: nil, assignee_agent_bot_id: nil })
                            .count

    Rails.logger.info("[QUEUE][size] Queue size=#{size} for account #{account.id}")

    size
  end

  private

  def next_assignable_entry
    waiting_entries.each do |entry|
      return entry unless inconsistent_queue_entry?(entry)

      reconcile_inconsistent_entry(entry)
    end

    Rails.logger.info("[QUEUE][fetch] No entries for account #{account.id}")
    nil
  end

  def waiting_entries
    ConversationQueue.for_account(account.id)
                     .waiting
                     .order(:position, :queued_at)
  end

  def lane_heads
    team_lane_heads + inbox_lane_heads
  end

  def team_lane_heads
    waiting_team_ids.filter_map do |team_id|
      ConversationQueue.lane_waiting(account.id, team_id: team_id, inbox_id: nil).first
    end
  end

  def inbox_lane_heads
    waiting_inbox_ids.filter_map do |inbox_id|
      ConversationQueue.lane_waiting(account.id, team_id: nil, inbox_id: inbox_id).first
    end
  end

  def waiting_conversation_ids
    ConversationQueue.for_account(account.id).waiting.unscope(:order).select(:conversation_id)
  end

  def waiting_team_ids
    Conversation.where(id: waiting_conversation_ids).where.not(team_id: nil).distinct.pluck(:team_id)
  end

  def waiting_inbox_ids
    Conversation.where(id: waiting_conversation_ids).where(team_id: nil).distinct.pluck(:inbox_id)
  end

  def inconsistent_queue_entry?(entry)
    conversation = entry.conversation
    return false unless conversation

    conversation.assignee_id.present? || conversation.assignee_agent_bot_id.present?
  end

  def reconcile_inconsistent_entry(entry)
    conversation = entry.conversation
    cid = conversation.id

    Rails.logger.warn(
      "[QUEUE][reconcile][conv=#{cid}] Removing queue entry: conversation has assignee " \
      "(user=#{conversation.assignee_id.inspect}, bot=#{conversation.assignee_agent_bot_id.inspect})"
    )

    ChatQueue::QueueService.new(account: account).remove_from_queue(conversation, reason: :other)
    conversation.update!(status: :open) if conversation.queued?

    nil
  end
end
