module Search::TimeWindow
  private

  def apply_time_filter(query, column_name)
    return query if params[:since].blank? && params[:until].blank?

    query = query.where("#{column_name} >= ?", cap_since_time(params[:since])) if params[:since].present?
    query = query.where("#{column_name} <= ?", cap_until_time(params[:until])) if params[:until].present?
    query
  end

  def cap_since_time(since_param)
    [Time.zone.at(since_param.to_i), 90.days.ago].max
  end

  def cap_until_time(until_param)
    [Time.zone.at(until_param.to_i), 90.days.from_now].min
  end
end
