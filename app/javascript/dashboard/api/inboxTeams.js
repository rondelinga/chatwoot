/* global axios */
import ApiClient from './ApiClient';

class InboxTeams extends ApiClient {
  constructor() {
    super('inbox_teams', { accountScoped: true });
  }

  show(inboxId) {
    return axios.get(this.url, { params: { inbox_id: inboxId } });
  }

  update({ inboxId, teamConfigs }) {
    return axios.patch(this.url, {
      inbox_id: inboxId,
      team_configs: teamConfigs,
    });
  }
}

export default new InboxTeams();
