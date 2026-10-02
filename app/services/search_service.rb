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
end

SearchService.prepend_mod_with('SearchService')
