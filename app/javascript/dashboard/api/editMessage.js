/* global axios */
import ApiClient from './ApiClient';

class EditMessageApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  edit(conversationId, messageId, content) {
    return axios.patch(
      `${this.url}/${conversationId}/messages/${messageId}/content`,
      { content }
    );
  }
}

export default new EditMessageApi();
