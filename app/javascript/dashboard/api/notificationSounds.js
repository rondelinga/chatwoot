/* global axios */
import ApiClient from './ApiClient';

class NotificationSoundsAPI extends ApiClient {
  constructor() {
    super('profile/notification_sounds', { accountScoped: false });
  }

  create(file) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(this.url, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }
}

export default new NotificationSoundsAPI();
