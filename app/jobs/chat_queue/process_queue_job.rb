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

    assign_up_to_capacity(queue_service, account)

    schedule_or_stop(queue_service, account_id)
  end

  def assign_up_to_capacity(queue_service, account)
    capacity_service = ChatQueue::Agents::CapacityService.new(account: account)
    available_slots = capacity_service.available_slots

    if available_slots&.zero?
      Rails.logger.info "[QUEUE][JOB] No available capacity (active=#{capacity_service.active_chats_count}, " \
                        "limits=#{capacity_service.total_online_limits})"
      return
    end

    max_assignments = if available_slots.nil?
                        queue_service.queue_size
                      else
                        [available_slots, queue_service.queue_size].min
                      end

    Rails.logger.info "[QUEUE][JOB] Assigning up to #{max_assignments} conversations " \
                      "(available_slots=#{available_slots.inspect}, queue=#{queue_service.queue_size})"

    max_assignments.times do |attempt|
      conv = fetch_conversation_or_stop(account)
      break unless conv

      log_conversation(conv)
      Rails.logger.info "[QUEUE][JOB] Assignment attempt #{attempt + 1}/#{max_assignments}"
      break unless try_assign(queue_service, conv, account)
    end
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

  def fetch_conversation_or_stop(account)
    entry = ChatQueue::Queue::FetchService.new(account: account).fetch_queue_entry
    return nil unless entry

    entry
  end

  def log_conversation(conv)
    Rails.logger.info "[QUEUE][JOB] Picked conversation_queue_id=#{conv.id} conv_id=#{conv.conversation_id} position=#{conv.position}"
  end

  def try_assign(queue_service, conv, account)
    conversation = Conversation.find_by(id: conv.conversation_id)
    return false unless conversation

    return true if try_agents_for_tier(queue_service, conv, conversation, :primary)

    try_agents_for_tier(queue_service, conv, conversation, :backup)
  end

  def try_agents_for_tier(queue_service, conv, conversation, tier)
    agent_ids = ChatQueue::Agents::OnlineAgentsService.new(
      account: conversation.account,
      team_id: conversation.team_id,
      assignment_tier: tier
    ).list

    Rails.logger.info "[QUEUE][JOB] Online #{tier} agents sorted: #{agent_ids.inspect}"
    return false if agent_ids.empty?

    agents = User.where(id: agent_ids).index_by(&:id)
    Rails.logger.info "[QUEUE][JOB] Loaded #{tier} agents: #{agents.keys.inspect}"

    agent_ids.each do |agent_id|
      agent = agents[agent_id]

      unless agent
        Rails.logger.info "[QUEUE][JOB] Agent #{agent_id} is missing, skipping"
        next
      end

      Rails.logger.info "[QUEUE][JOB] Trying to assign conv_id=#{conv.conversation_id} to #{tier} agent_id=#{agent.id}"

      if queue_service.assign_specific_from_queue!(agent, conv.conversation_id)
        Rails.logger.info "[QUEUE][JOB] SUCCESS assigned conv_id=#{conv.conversation_id} to agent_id=#{agent.id}"
        return true
      end

      Rails.logger.info "[QUEUE][JOB] FAIL assign to agent_id=#{agent.id}, trying next"
    end

    false
  end

  def schedule_or_stop(queue_service, account_id)
    if queue_service.queue_size.positive?
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
