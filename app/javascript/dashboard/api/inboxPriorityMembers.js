/* global axios */
import ApiClient from './ApiClient';

class InboxPriorityMembers extends ApiClient {
  constructor() {
    super('inbox_priority_members', { accountScoped: true });
  }

  update({ inboxId, userIds }) {
    return axios.patch(this.url, {
      inbox_id: inboxId,
      user_ids: userIds,
    });
  }
}

export default new InboxPriorityMembers();
