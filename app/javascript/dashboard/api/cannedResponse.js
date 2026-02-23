/* global axios */

import ApiClient from './ApiClient';

class CannedResponse extends ApiClient {
  constructor() {
    super('canned_responses', { accountScoped: true });
  }

  get({ searchKey, all = false }) {
    const params = new URLSearchParams();
    if (searchKey) params.append('search', searchKey);
    if (all) params.append('all', true);
    const query = params.toString();
    return axios.get(query ? `${this.url}?${query}` : this.url);
  }
}

export default new CannedResponse();
