class SearchService
  include Search::TimeWindow
  include Search::InboxAccess
  include Search::MessageFilters

  pattr_initialize [:current_user!, :current_account!, :params!, :search_type!]

  def account_user
    @account_user ||= current_account.account_users.find_by(user: current_user)
  end

  def perform
    case search_type
    when 'Message'
      { messages: filter_messages }
    when 'Conversation'
      { conversations: filter_conversations }
    when 'Contact'
      { contacts: filter_contacts }
    when 'Article'
      { articles: filter_articles }
    else
      {
        contacts: filter_contacts,
        messages: filter_messages,
        conversations: filter_conversations,
        articles: filter_articles
      }
    end
  end

  private

  def accessable_inbox_ids
    @accessable_inbox_ids ||= @current_user.assigned_inboxes.pluck(:id)
  end

  def search_query
    @search_query ||= params[:q].to_s.strip
  end

  def filter_conversations
    conversations_query = current_account.conversations.where(inbox_id: accessable_inbox_ids)
                                         .joins('INNER JOIN contacts ON conversations.contact_id = contacts.id')
                                         .where("cast(conversations.display_id as text) ILIKE :search OR contacts.name ILIKE :search OR contacts.email
                            ILIKE :search OR contacts.phone_number ILIKE :search OR contacts.identifier ILIKE :search
                            OR conversations.additional_attributes->>'mail_subject' ILIKE :search", search: "%#{search_query}%")

    conversations_query = Conversations::AgentAccessService.apply_scope(conversations_query, current_user, current_account)

    if current_account.feature_enabled?('advanced_search')
      conversations_query = apply_time_filter(conversations_query,
                                              'conversations.last_activity_at')
    end

    @conversations = conversations_query.order('conversations.created_at DESC')
                                        .page(params[:page])
                                        .per(15)
  end

  def advanced_search_with_fallback
    advanced_search.load
  rescue Faraday::Error, Searchkick::Error, OpenSearch::Transport::Transport::Error => e
    Rails.logger.warn("Elasticsearch unavailable, falling back to SQL search: #{e.message}")
    ChatwootExceptionTracker.new(e, user: current_user, account: current_account).capture_exception
    use_gin_search ? filter_messages_with_gin : filter_messages_with_like
  end

  def filter_messages_with_gin
    base_query = message_base_query
    base_query = apply_message_filters(base_query)

    if search_query.present?
      # Use the @@ operator with to_tsquery for better GIN index utilization
      # Convert search query to tsquery format with prefix matching

      # Use this if we wanna match splitting the words
      # split_query = search_query.split.map { |term| "#{term} | #{term}:*" }.join(' & ')

      # This will do entire sentence matching using phrase distance operator
      tsquery = search_query.split.join(' <-> ')

      # Apply the text search using the GIN index
      base_query.where('content @@ to_tsquery(?)', tsquery)
                .reorder('messages.created_at DESC, messages.id DESC')
                .page(params[:page])
                .per(15)
    else
      base_query.reorder('messages.created_at DESC, messages.id DESC')
                .page(params[:page])
                .per(15)
    end
  end

  def filter_messages_with_like
    base_query = message_base_query
    base_query = apply_message_filters(base_query)
    base_query.where('messages.content ILIKE :search', search: "%#{search_query}%")
              .reorder('messages.created_at DESC, messages.id DESC')
              .page(params[:page])
              .per(15)
  end

  def message_base_query
    query = current_account.messages.where('created_at >= ?', search_window_start)
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

  def filter_contacts
    return Contact.none.page(params[:page]).per(15) if restricted_agent?

    contacts_query = current_account.contacts.where(
      "name ILIKE :search OR email ILIKE :search OR phone_number
      ILIKE :search OR identifier ILIKE :search", search: "%#{search_query}%"
    )

    contacts_query = apply_time_filter(contacts_query, 'last_activity_at') if current_account.feature_enabled?('advanced_search')

    contacts_query = apply_contact_access_scope(contacts_query)

    @contacts = contacts_query.resolved_contacts(
      use_crm_v2: current_account.feature_enabled?('crm_v2')
    ).order_on_last_activity_at('desc').page(params[:page]).per(15)
  end

  def apply_contact_access_scope(contacts_query)
    contacts_query
  end

  def restricted_agent?
    Conversations::AgentAccessService.restricted_agent?(account_user)
  end

  def filter_articles
    articles_query = current_account.articles.text_search(search_query)
    articles_query = apply_time_filter(articles_query, 'updated_at') if current_account.feature_enabled?('advanced_search')

    @articles = articles_query.page(params[:page]).per(15)
  end

  def search_window_start
    Limits.search_time_range_limit_days.days.ago
  end

  def cap_since_time(since_param)
    requested_time = Time.zone.at(since_param.to_i)

    # Silently cap to the search window start if requested time is too far back
    [requested_time, search_window_start].max
  end
end

SearchService.prepend_mod_with('SearchService')
