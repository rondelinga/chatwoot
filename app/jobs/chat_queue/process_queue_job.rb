class ChatQueue::ProcessQueueJob < MutexApplicationJob
  queue_as :queue_processing

  retry_on LockAcquisitionError, wait: 1.second, attempts: 10

  LOCK_KEY = 'CHAT_QUEUE:PROCESS:%<account_id>s'.freeze

  def perform(account_id)
    with_lock(format(LOCK_KEY, account_id: account_id)) do
      process_account_queue(account_id)
    end
  end

  private

  def process_account_queue(account_id)
    log_start(account_id)

    account = fetch_account_or_stop(account_id)
    return unless account

    queue_service = ChatQueue::QueueService.new(account: account)

    return if queue_empty?(queue_service, account)

    assigned = assign_up_to_capacity(queue_service, account)

    schedule_or_stop(queue_service, account_id, assigned)
  end

  # Returns how many conversations were assigned in this pass
  def assign_up_to_capacity(queue_service, account)
    capacity_service = ChatQueue::Agents::CapacityService.new(account: account)
    available_slots = capacity_service.available_slots
    return 0 if log_no_capacity(capacity_service, available_slots)

    max_assignments = assignment_limit(available_slots, queue_service)
    log_assignment_plan(max_assignments, available_slots, queue_service)
    assign_next_conversations(queue_service, account, max_assignments)
  end

  def log_no_capacity(capacity_service, available_slots)
    return false unless available_slots&.zero?

    Rails.logger.info "[QUEUE][JOB] No available capacity (active=#{capacity_service.active_chats_count}, " \
                      "limits=#{capacity_service.total_online_limits})"
    true
  end

  def assignment_limit(available_slots, queue_service)
    available_slots.nil? ? queue_service.queue_size : [available_slots, queue_service.queue_size].min
  end

  def log_assignment_plan(max_assignments, available_slots, queue_service)
    Rails.logger.info "[QUEUE][JOB] Assigning up to #{max_assignments} conversations " \
                      "(available_slots=#{available_slots.inspect}, queue=#{queue_service.queue_size})"
  end

  def assign_next_conversations(queue_service, account, max_assignments)
    fetch_service = ChatQueue::Queue::FetchService.new(account: account)
    skipped_lanes = []
    assigned = 0

    while assigned < max_assignments
      entry = fetch_service.oldest_assignable_head(skipped_lanes)
      break unless entry

      log_conversation(entry)
      Rails.logger.info "[QUEUE][JOB] Assignment #{assigned + 1}/#{max_assignments} lane=#{fetch_service.lane_key(entry).inspect}"
      if try_assign(queue_service, entry, account)
        assigned += 1
      else
        skipped_lanes << fetch_service.lane_key(entry)
      end
    end
    assigned
  end

  def log_start(account_id)
    Rails.logger.info "[QUEUE][JOB] Start for account=#{account_id}"
  end

  def fetch_account_or_stop(account_id)
    account = find_active_account(account_id)
    unless account
      Rails.logger.info '[QUEUE][JOB] Stop: account not found or queue disabled'
      return nil
    end
    account
  end

  def queue_empty?(queue_service, account)
    size = queue_service.queue_size
    Rails.logger.info "[QUEUE][JOB] Current queue_size=#{size} for account=#{account.id}"
    size.zero?
  end

  def log_conversation(conv)
    Rails.logger.info "[QUEUE][JOB] Picked conversation_queue_id=#{conv.id} conv_id=#{conv.conversation_id} position=#{conv.position}"
  end

  def try_assign(queue_service, conv, account)
    conversation = Conversation.find_by(id: conv.conversation_id)
    return false unless conversation

    agent = ChatQueue::Agents::SelectorService.new(account: account).pick_best_agent_for(conversation)
    return false unless agent

    Rails.logger.info "[QUEUE][JOB] Assigning conv_id=#{conv.conversation_id} to agent_id=#{agent.id}"
    queue_service.assign_specific_from_queue!(agent, conv.conversation_id).present?
  end

  # A pass that assigned nothing stops here: the queue is picked up again by the events that can
  # free a slot (agent comes online, chat resolved or unassigned, new chat, limit change)
  def schedule_or_stop(queue_service, account_id, assigned)
    if assigned.zero?
      Rails.logger.info '[QUEUE][JOB] Nothing assigned, waiting for an agent or a free slot'
    elsif queue_service.queue_size.positive?
      Rails.logger.info '[QUEUE][JOB] Queue still has items, scheduling next run'
      ChatQueue::ProcessQueueJob.perform_later(account_id)
    else
      Rails.logger.info '[QUEUE][JOB] Queue empty after assign, stopping'
    end
  end

  def find_active_account(account_id)
    account = Account.find_by(id: account_id)
    return nil unless account&.queue_enabled?

    account
  end
end
