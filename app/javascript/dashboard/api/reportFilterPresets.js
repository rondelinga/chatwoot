/* global axios */
import ApiClient from './ApiClient';

class ReportFilterPresetsAPI extends ApiClient {
  constructor() {
    super('report_filter_presets', { accountScoped: true });
  }

  get(params = {}) {
    return axios.get(this.url, { params });
  }
}

export default new ReportFilterPresetsAPI();
