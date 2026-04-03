module ConversationFinderOverride
  def self.prepended(base)
    base::SORT_OPTIONS.merge!(
      'priority_desc_created_at_asc' => %w[sort_on_priority_created_at desc]
    )
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

  def set_up
    set_inboxes
    set_team
    set_assignee_type

    find_all_conversations
    filter_by_created_at
    filter_by_status unless params[:q]
    filter_by_team
    filter_by_labels
    filter_by_query
    filter_by_source_id
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

    if value.match?(/\d{2}:\d{2}/)
      time
    else
      type == :from ? time.beginning_of_day : time.end_of_day
    end
  rescue ArgumentError => e
    Rails.logger.warn("Failed to parse created_at value '#{value}': #{e.message}")
    nil
  end
end

ConversationFinder.prepend(ConversationFinderOverride)
