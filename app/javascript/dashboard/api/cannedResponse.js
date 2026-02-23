/* global axios */
import CacheEnabledApiClient from './CacheEnabledApiClient';

class CannedResponse extends CacheEnabledApiClient {
  constructor() {
    super('canned_responses', { accountScoped: true });
  }

  // eslint-disable-next-line class-methods-use-this
  get cacheModelName() {
    return 'canned_response';
  }

  // The index endpoint returns a bare array instead of a payload wrapper
  // eslint-disable-next-line class-methods-use-this
  extractDataFromResponse(response) {
    return response.data;
  }

  // eslint-disable-next-line class-methods-use-this
  marshallData(dataToParse) {
    return { data: dataToParse };
  }

  get(params = false) {
    if (typeof params !== 'object' || params === null) {
      return super.get(params);
    }

    const { searchKey, all = false, inboxId = null } = params;
    const searchParams = new URLSearchParams();
    if (searchKey) searchParams.append('search', searchKey);
    if (all) searchParams.append('all', true);
    if (inboxId) searchParams.append('inbox_id', inboxId);

    const query = searchParams.toString();
    return axios.get(query ? `${this.url}?${query}` : this.url);
  }
}

export default new CannedResponse();
