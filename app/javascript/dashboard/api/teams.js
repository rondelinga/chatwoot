/* global axios */
// import ApiClient from './ApiClient';
import CacheEnabledApiClient from './CacheEnabledApiClient';

export class TeamsAPI extends CacheEnabledApiClient {
  constructor() {
    super('teams', { accountScoped: true });
  }

  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    return 'team';
  }

  // eslint-disable-next-line class-methods-use-this
  extractDataFromResponse(response) {
    return response.data;
  }

  // eslint-disable-next-line class-methods-use-this
  marshallData(dataToParse) {
    return { data: dataToParse };
  }

  getAgents({ teamId }) {
    return axios.get(`${this.url}/${teamId}/team_members`);
  }

  addAgents({ teamId, primaryUserIds, backupUserIds }) {
    return axios.post(`${this.url}/${teamId}/team_members`, {
      primary_user_ids: primaryUserIds,
      backup_user_ids: backupUserIds,
    });
  }

  updateAgents({ teamId, primaryUserIds, backupUserIds }) {
    return axios.patch(`${this.url}/${teamId}/team_members`, {
      primary_user_ids: primaryUserIds,
      backup_user_ids: backupUserIds,
    });
  }
}

export default new TeamsAPI();
