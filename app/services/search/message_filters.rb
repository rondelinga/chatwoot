module Search::MessageFilters
  private

  def filter_messages
    @messages = if use_gin_search
                  filter_messages_with_gin
                elsif should_run_advanced_search?
                  advanced_search_with_fallback
                else
                  filter_messages_with_like
                end
  end

  def advanced_search_with_fallback
    advanced_search
  rescue Faraday::ConnectionFailed, Searchkick::Error, Elasticsearch::Transport::Transport::Error => e
    Rails.logger.warn("Elasticsearch unavailable, falling back to SQL search: #{e.message}")
    use_gin_search ? filter_messages_with_gin : filter_messages_with_like
  end

  def should_run_advanced_search?
    ChatwootApp.advanced_search_allowed? && current_account.feature_enabled?('advanced_search')
  end

  def advanced_search; end

  def filter_messages_with_gin
    base_query = apply_message_filters(message_base_query)
    return paginated_messages(base_query) if search_query.blank?

    # Use the @@ operator with to_tsquery for better GIN index utilization
    # Convert search query to tsquery format with prefix matching
    # This will do entire sentence matching using phrase distance operator
    tsquery = search_query.split.join(' <-> ')
    paginated_messages(base_query.where('content @@ to_tsquery(?)', tsquery))
  end

  def filter_messages_with_like
    base_query = apply_message_filters(message_base_query)
    paginated_messages(base_query.where('messages.content ILIKE :search', search: "%#{search_query}%"))
  end

  def paginated_messages(query)
    query.reorder('messages.created_at DESC, messages.id DESC').page(params[:page]).per(15)
  end

  def message_base_query
    query = current_account.messages.where('created_at >= ?', 3.months.ago)
    query = query.where(inbox_id: accessable_inbox_ids) unless should_skip_inbox_filtering?
    apply_agent_message_scope(query)
  end

  def apply_agent_message_scope(query)
    return query unless restricted_agent?

    allowed_conversations = Conversations::AgentAccessService.apply_scope(
      current_account.conversations.where(inbox_id: accessable_inbox_ids),
      current_user,
      current_account
    )
    query.where(conversation_id: allowed_conversations.select(:id))
  end

  def apply_message_filters(query)
    return query unless current_account.feature_enabled?('advanced_search')

    query = apply_time_filter(query, 'messages.created_at')
    query = apply_sender_filter(query)
    apply_inbox_id_filter(query)
  end

  def apply_sender_filter(query)
    sender_type, sender_id = parse_from_param(params[:from])
    return query unless sender_type && sender_id

    query.where(sender_type: sender_type, sender_id: sender_id)
  end

  def parse_from_param(from_param)
    return [nil, nil] unless from_param&.match?(/\A(contact|agent):\d+\z/)

    type, id = from_param.split(':')
    sender_type = type == 'agent' ? 'User' : 'Contact'
    [sender_type, id.to_i]
  end

  def use_gin_search
    current_account.feature_enabled?('search_with_gin')
  end
end
