class AddUniqueIndexToCsatSurveyResponsesConversationId < ActiveRecord::Migration[7.1]
  def change
    # rubocop:disable Rails/ReversibleMigration -- dedupe before adding unique index
    execute <<-SQL.squish
      DELETE FROM csat_survey_responses
      WHERE id NOT IN (
        SELECT MAX(id)
        FROM csat_survey_responses
        GROUP BY conversation_id
      )
    SQL

    remove_index :csat_survey_responses, :conversation_id
    add_index :csat_survey_responses, :conversation_id, unique: true
    # rubocop:enable Rails/ReversibleMigration
  end
end
