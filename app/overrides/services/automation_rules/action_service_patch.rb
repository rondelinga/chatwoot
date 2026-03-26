module Overrides
  module AutomationRules::ActionServicePatch
    private

    def send_email_to_team(params)
      teams = Team.where(id: params[0][:team_ids])

      teams.each do |team|
        # TeamNotifications::AutomationNotificationMailer.conversation_creation(@conversation, team, params[0][:message])&.deliver_now
      end
    end
  end
end

AutomationRules::ActionService.prepend(Overrides::AutomationRules::ActionServicePatch)
