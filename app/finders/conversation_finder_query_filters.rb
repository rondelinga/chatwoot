module ConversationFinderQueryFilters
  private

  def filter_by_assignee_type
    case @assignee_type
    when 'me'
      @conversations = @conversations.assigned_to(current_user)
    when 'unassigned'
      @conversations = @conversations.unassigned
    when 'assigned'
      @conversations = @conversations.assigned
    end
    @conversations
  end

  def filter_by_agent
    return unless params[:agent_id]

    @conversations = @conversations.where(assignee_id: params[:agent_id])
    return if params[:q].blank?

    allowed_types = [Message.message_types[:incoming], Message.message_types[:outgoing]]
    @conversations = @conversations.joins(:messages).where('messages.content ILIKE :q',
                                                           q: "%#{params[:q]}%").where(messages: { message_type: allowed_types })
  end

  def filter_by_conversation_type
    case @params[:conversation_type]
    when 'mention'
      conversation_ids = current_account.mentions.where(user: current_user).pluck(:conversation_id)
      @conversations = @conversations.where(id: conversation_ids)
    when 'participating'
      participant_conversation_ids = ConversationParticipant.where(account_id: current_account.id, user_id: current_user.id).select(:conversation_id)
      @conversations = @conversations.where(id: participant_conversation_ids)
    when 'unattended'
      @conversations = @conversations.unattended
    end
    @conversations
  end

  def filter_by_query
    return unless params[:q]

    allowed_message_types = [Message.message_types[:incoming], Message.message_types[:outgoing]]
    @conversations = conversations.joins(:messages).where('messages.content ILIKE :search', search: "%#{params[:q]}%")
                                  .where(messages: { message_type: allowed_message_types }).includes(:messages)
                                  .where('messages.content ILIKE :search', search: "%#{params[:q]}%")
                                  .where(messages: { message_type: allowed_message_types })
  end

  def filter_by_status
    return if params[:status] == 'all'

    @conversations = @conversations.where(status: params[:status] || ConversationFinder::DEFAULT_STATUS)
  end

  def filter_by_team
    return unless @team

    @conversations = @conversations.where(team: @team)
  end

  def filter_by_labels
    return unless params[:labels]

    @conversations = @conversations.tagged_with(params[:labels], any: true)
  end

  def filter_by_source_id
    return unless params[:source_id]

    @conversations = @conversations.joins(:contact_inbox)
    @conversations = @conversations.where(contact_inboxes: { source_id: params[:source_id] })
  end

  def filter_by_created_at
    return if params[:created_from].blank? && params[:created_to].blank?

    from_time = parse_created_at(params[:created_from], :from) || Time.zone.at(0)
    to_time   = parse_created_at(params[:created_to], :to) || Time.zone.now
    @conversations = @conversations.where(created_at: from_time..to_time)
  end

  def parse_created_at(value, type)
    return nil if value.blank?

    time = Time.zone.parse(value)
    return nil unless time
    return time if value.match?(/\d{2}:\d{2}/)

    type == :from ? time.beginning_of_day : time.end_of_day
  rescue ArgumentError => e
    Rails.logger.warn("Failed to parse created_at value '#{value}': #{e.message}")
    nil
  end
end
