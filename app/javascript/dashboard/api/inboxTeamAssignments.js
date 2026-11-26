/* global axios */
import ApiClient from './ApiClient';

class InboxTeamAssignments extends ApiClient {
  constructor() {
    super('inbox_team_assignments', { accountScoped: true });
  }

  create(sets) {
    return axios.post(this.url, { sets });
  }
}

export default new InboxTeamAssignments();
