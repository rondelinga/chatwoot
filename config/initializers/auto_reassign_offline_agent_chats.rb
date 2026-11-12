module OnlineStatusTrackerPatch
  def set_status(account_id, user_id, status)
    result = super
    if status.to_s == 'offline'
      Rails.logger.debug { "Agent #{user_id} went offline in account #{account_id} -> reassign chats" }
      ReassignOfflineAgentChatsJob.set(wait: 1.minute).perform_later(user_id, account_id)
    end
    result
  end

  # An online agent who reopens the app becomes available again without a status change,
  # so the queue (which stops while nobody can take a chat) has to be picked up here
  def update_presence(account_id, obj_type, obj_id)
    return super unless obj_type == 'User'

    was_present = get_presence(account_id, obj_type, obj_id)
    result = super
    process_queue_when_agent_returns(account_id) if !was_present && get_status(account_id, obj_id) == 'online'
    result
  end

  private

  def process_queue_when_agent_returns(account_id)
    ChatQueue::ProcessQueueJob.perform_later(account_id) if Account.find_by(id: account_id)&.queue_enabled?
  end
end

Rails.application.config.to_prepare do
  OnlineStatusTracker.singleton_class.prepend(OnlineStatusTrackerPatch)
  Rails.logger.info 'OnlineStatusTracker patched successfully'
end
