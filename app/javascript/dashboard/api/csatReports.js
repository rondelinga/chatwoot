/* global axios */
import ApiClient from './ApiClient';

const excludedLabelParams = excludedLabels => {
  if (!excludedLabels?.length) return {};

  return { 'excluded_labels[]': excludedLabels };
};

class CSATReportsAPI extends ApiClient {
  constructor() {
    super('csat_survey_responses', { accountScoped: true });
  }

  get({
    page,
    from,
    to,
    user_ids,
    inbox_ids,
    team_ids,
    rating,
    excluded_labels: excludedLabels,
  } = {}) {
    return axios.get(this.url, {
      params: {
        page,
        since: from,
        until: to,
        sort: '-created_at',
        user_ids,
        inbox_ids,
        team_ids,
        rating,
        ...excludedLabelParams(excludedLabels),
      },
    });
  }

  download({
    from,
    to,
    user_ids,
    inbox_ids,
    team_ids,
    rating,
    excluded_labels: excludedLabels,
    format = 'csv',
  } = {}) {
    return axios.get(`${this.url}/download.${format}`, {
      params: {
        since: from,
        until: to,
        sort: '-created_at',
        user_ids,
        inbox_ids,
        team_ids,
        rating,
        ...excludedLabelParams(excludedLabels),
      },
      responseType: format === 'xlsx' ? 'blob' : undefined,
    });
  }

  getMetrics({
    from,
    to,
    user_ids,
    inbox_ids,
    team_ids,
    rating,
    excluded_labels: excludedLabels,
  } = {}) {
    return axios.get(`${this.url}/metrics`, {
      params: {
        since: from,
        until: to,
        user_ids,
        inbox_ids,
        team_ids,
        rating,
        ...excludedLabelParams(excludedLabels),
      },
    });
  }
}

export default new CSATReportsAPI();
