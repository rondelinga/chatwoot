class ConversationFinder
  include ConversationFinderFilters
  include ConversationFinderQueryFilters

  attr_reader :current_user, :current_account, :params

  DEFAULT_STATUS = 'open'.freeze
  # assumptions
  # inbox_id if not given, take from all conversations, else specific to inbox
  # assignee_type if not given, take 'all'
  # conversation_status if not given, take 'open'

  # response of this class will be of type
  # {conversations: [array of conversations], count: {open: count, resolved: count}}

  # params
  # assignee_type, inbox_id, :status

  def initialize(current_user, params)
    @current_user = current_user
    @current_account = current_user.account
    @is_admin = current_account.account_users.find_by(user_id: current_user.id)&.administrator?
    @params = params
  end

  def perform
    set_up

    mine_count, unassigned_count, all_count = set_count_for_all_conversations
    assigned_count = all_count - unassigned_count

    filter_by_assignee_type

    {
      conversations: conversations,
      count: { mine_count: mine_count, assigned_count: assigned_count, unassigned_count: unassigned_count, all_count: all_count }
    }
  end

  def perform_meta_only
    set_up

    mine_count, unassigned_count, all_count, = set_count_for_all_conversations
    assigned_count = all_count - unassigned_count

    {
      count: {
        mine_count: mine_count,
        assigned_count: assigned_count,
        unassigned_count: unassigned_count,
        all_count: all_count
      }
    }
  end

  private

  def set_count_for_all_conversations
    return legacy_count_for_all_conversations if @conversations.limit_value || @conversations.offset_value || @conversations.eager_loading?

    counts = @conversations.unscope(:order).pick(
      Arel.sql("COUNT(*) FILTER (WHERE assignee_id = #{current_user.id})"),
      Arel.sql('COUNT(*) FILTER (WHERE assignee_id IS NULL AND assignee_agent_bot_id IS NULL)'),
      Arel.sql('COUNT(*)')
    )
    counts || [0, 0, 0]
  end

  def legacy_count_for_all_conversations
    [
      @conversations.assigned_to(current_user).count,
      @conversations.unassigned.count,
      @conversations.count
    ]
  end

  def current_page
    params[:page] || 1
  end

  def conversations_base_query
    @conversations.includes(
      :taggings, :team, :contact_inbox, { assignee: { avatar_attachment: [:blob] } }, { contact: { avatar_attachment: [:blob] } }
    ).preload(inbox: :channel, ai_assignee: { avatar_attachment: [:blob] })
  end

  def conversations
    @conversations = conversations_base_query
    @conversations = Conversations::SortService.apply(@conversations, params[:sort_by])

    if params[:updated_within].present?
      @conversations.where('conversations.updated_at > ?', Time.zone.now - params[:updated_within].to_i.seconds)
    else
      @conversations.page(current_page).per(ENV.fetch('CONVERSATION_RESULTS_PER_PAGE', '25').to_i)
    end
  end
end
ConversationFinder.prepend_mod_with('ConversationFinder')
