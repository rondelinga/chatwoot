class ChatQueue::Queue::UrgentHeadService
  pattr_initialize [:account!, :skipped_lane_keys!]

  def perform
    available_memberships.filter_map { |inbox_id, user_ids| oldest_entry(inbox_id, user_ids) }
                         .min_by { |entry| [entry.queued_at, entry.id] }
  end

  private

  def available_memberships
    rows = urgent_rows
    return {} if rows.empty?

    available_ids = available_user_ids(rows.map(&:last).uniq)
    return {} if available_ids.empty?

    group_memberships(rows, available_ids)
  end

  def urgent_rows
    InboxMember.where(urgent: true, inbox_id: queued_inbox_ids).pluck(:inbox_id, :user_id)
  end

  def group_memberships(rows, available_ids)
    rows.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(inbox_id, user_id), grouped|
      grouped[inbox_id] << user_id if available_ids.include?(user_id)
    end
  end

  def available_user_ids(user_ids)
    online_ids = online_user_ids & user_ids
    return [] if online_ids.empty?

    online_ids - AgentActiveChatLimits.over_limit_ids(account, online_ids)
  end

  def online_user_ids
    (OnlineStatusTracker.get_available_users(account.id) || {})
      .select { |_id, status| status == 'online' }
      .keys
      .map(&:to_i)
  end

  def queued_inbox_ids
    ConversationQueue.for_account(account.id).waiting.unscope(:order).distinct.pluck(:inbox_id)
  end

  def oldest_entry(inbox_id, user_ids)
    team_ids = allowed_team_ids(inbox_id, user_ids)
    return if team_ids.empty?

    waiting_entries(inbox_id).where(conversations: { team_id: team_ids }).order(:queued_at, :id).first
  end

  def allowed_team_ids(inbox_id, user_ids)
    team_ids = TeamMember.where(user_id: user_ids).distinct.pluck(:team_id)
    team_ids -= skipped_team_ids
    team_ids << nil unless skipped_lane_keys.include?([:inbox, inbox_id])
    team_ids
  end

  def skipped_team_ids
    skipped_lane_keys.filter_map { |kind, id| id if kind == :team }
  end

  def waiting_entries(inbox_id)
    ConversationQueue.for_account(account.id)
                     .waiting
                     .unscope(:order)
                     .joins(:conversation)
                     .where(inbox_id: inbox_id)
  end
end
