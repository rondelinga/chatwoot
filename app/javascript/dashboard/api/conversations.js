/* global axios */
import ApiClient from './ApiClient';

class ConversationApi extends ApiClient {
  constructor() {
    super('conversations', { accountScoped: true });
  }

  getLabels(conversationID) {
    return axios.get(`${this.url}/${conversationID}/labels`);
  }

  getCampaignHistory(conversationId, { before, signal } = {}) {
    return axios.get(`${this.url}/${conversationId}/campaign_history`, {
      params: { before },
      signal,
    });
  }

  updateLabels(conversationID, labels) {
    return axios.post(`${this.url}/${conversationID}/labels`, { labels });
  }

  getSuggestions(conversationID, type) {
    return axios.get(`${this.url}/${conversationID}/suggestions/${type}`);
  }

  changeInbox(conversationID, inboxID) {
    return axios.patch(`${this.url}/${conversationID}/change_inbox`, {
      inbox_id: inboxID,
    });
  }

  getQueue(conversationId) {
    return axios.get(`${this.url}/${conversationId}/queue`);
  }

  leaveQueue(conversationId) {
    return axios.delete(`${this.url}/${conversationId}/queue`);
  }

  hideConversation(conversationId) {
    return axios.post(`${this.url}/${conversationId}/mark_resolved_dismissed`);
  }

  getUnreadCounts() {
    return axios.get(`${this.url}/unread_counts`);
  }
}

export default new ConversationApi();
