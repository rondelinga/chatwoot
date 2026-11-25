/* global axios */
import ApiClient from './ApiClient';

class ForceTransferApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  transfer(conversationId) {
    return axios.post(`${this.url}/${conversationId}/force_transfer`);
  }
}

export default new ForceTransferApi();
