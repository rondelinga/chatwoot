module Filters::LabelFilterHelper
  def tag_filter_query(query_hash, current_index)
    @filter_values["value_#{current_index}"] = filter_values(query_hash)
    match = tagging_match_sql
    tag_ids = "taggings.tag_id IN (SELECT tags.id FROM tags WHERE tags.name IN (:value_#{current_index}))"
    operator = query_hash[:query_operator]

    sql = case query_hash[:filter_operator]
          when 'equal_to' then "EXISTS (SELECT * FROM taggings WHERE #{match} AND #{tag_ids})"
          when 'not_equal_to' then "NOT EXISTS (SELECT * FROM taggings WHERE #{match} AND #{tag_ids})"
          when 'is_present' then "EXISTS (SELECT * FROM taggings WHERE #{match})"
          when 'is_not_present' then "NOT EXISTS (SELECT * FROM taggings WHERE #{match})"
          when 'contains_all'
            size = @filter_values["value_#{current_index}"].uniq.size
            "(SELECT COUNT(DISTINCT taggings.tag_id) FROM taggings WHERE #{match} AND #{tag_ids}) = #{size}"
          end
    "#{sql} #{operator}"
  end

  def csat_filter_query(query_hash)
    responses = "SELECT 1 FROM csat_survey_responses WHERE csat_survey_responses.conversation_id = #{filter_config[:table_name]}.id"
    query_operator = query_hash[:query_operator]

    case Array.wrap(query_hash['values']).first
    when 'rated'
      "EXISTS (#{responses}) #{query_operator}"
    when 'positive'
      "EXISTS (#{responses} AND csat_survey_responses.rating >= 4) #{query_operator}"
    when 'negative'
      "EXISTS (#{responses} AND csat_survey_responses.rating <= 2) #{query_operator}"
    when 'not_rated'
      "NOT EXISTS (#{responses}) #{query_operator}"
    else
      raise CustomExceptions::CustomFilter::InvalidValue.new(attribute_name: query_hash['attribute_key'])
    end
  end

  # Conversations that have at least one label and where every current label is tracked in
  # `automation_label_titles` (see Conversation#track_automation_label_titles /
  # #only_automation_labels?), i.e. every label was applied while an Automation Rule was
  # executing and none were added manually by an agent.
  def system_labels_filter_query(query_hash)
    table = filter_config[:table_name]
    labels_query = 'SELECT 1 FROM taggings INNER JOIN tags ON tags.id = taggings.tag_id ' \
                   "WHERE taggings.taggable_id = #{table}.id AND taggings.taggable_type = '#{filter_config[:entity]}' " \
                   "AND taggings.context = 'labels'"
    manual_labels_query = "#{labels_query} AND NOT (tags.name = ANY(#{table}.automation_label_titles))"

    "(EXISTS (#{labels_query}) AND NOT EXISTS (#{manual_labels_query})) #{query_hash[:query_operator]}"
  end

  private

  def tagging_match_sql
    "taggings.taggable_id = #{filter_config[:table_name]}.id AND taggings.taggable_type = '#{filter_config[:entity]}'"
  end
end
