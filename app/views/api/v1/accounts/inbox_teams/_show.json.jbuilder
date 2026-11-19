json.payload do
  json.teams do
    json.array! @teams do |team|
      json.partial! 'api/v1/models/team', formats: [:json], resource: team

      inbox_team = team.inbox_teams.detect { |it| it.inbox_id == @inbox.id }
      json.inbox_team do
        json.id inbox_team&.id
        json.is_default inbox_team&.is_default || false
        json.routing_type_id inbox_team&.routing_type_id
        json.agent_bot_id inbox_team&.agent_bot_id
      end
    end
  end
  json.agents do
    json.array! @agents do |agent|
      json.partial! 'api/v1/models/agent', formats: [:json], resource: agent
    end
  end
end
