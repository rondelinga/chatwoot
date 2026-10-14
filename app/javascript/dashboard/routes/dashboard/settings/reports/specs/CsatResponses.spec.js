import CsatResponses from '../CsatResponses.vue';

describe('CsatResponses.vue', () => {
  it('sends inbox and team filters under the param names the CSAT API reads', () => {
    const payload = CsatResponses.computed.requestPayload.call({
      from: 1,
      to: 2,
      userIds: [3],
      inboxIds: [4, 5],
      teamIds: [6],
      rating: null,
      excludedLabels: [],
      timeRange: { since: '00:00', until: '23:59' },
    });

    expect(payload).toMatchObject({ inbox_id: [4, 5], team_id: [6] });
    expect(payload).not.toHaveProperty('inbox_ids');
    expect(payload).not.toHaveProperty('team_ids');
  });
});
