import {
  buildPresetReportQuery,
  buildPresetSLAReportQuery,
  parsePresetDateRange,
  parsePresetFilters,
  pickByIds,
  serializePresetDateRange,
  serializeReportQuery,
  serializeSLAReportQuery,
} from './reportFilterPresetHelper';

const JAN_1 = Date.UTC(2024, 0, 1) / 1000;
const JAN_10_END = Date.UTC(2024, 0, 10, 23, 59, 59) / 1000;

describe('reportFilterPresetHelper', () => {
  describe('serializePresetDateRange', () => {
    it('stores the range type with the matching preset range id', () => {
      expect(
        serializePresetDateRange('last7days', [
          new Date(Date.UTC(2024, 0, 1)),
          new Date(Date.UTC(2024, 0, 7)),
        ])
      ).toEqual({
        rangeType: 'last7days',
        dateRangeId: 'LAST_7_DAYS',
        customDateRange: [
          '2024-01-01T00:00:00.000Z',
          '2024-01-07T00:00:00.000Z',
        ],
      });
      expect(serializePresetDateRange('thisWeek', []).dateRangeId).toBeNull();
    });
  });

  describe('parsePresetDateRange', () => {
    it('recalculates relative ranges from the range type or the old range id', () => {
      const today = new Date().toDateString();

      [{ rangeType: 'today' }, { dateRangeId: 'TODAY' }].forEach(filters => {
        const { rangeType, dateRange } = parsePresetDateRange(filters);
        expect(rangeType).toBe('today');
        expect(dateRange.map(date => date.toDateString())).toEqual([
          today,
          today,
        ]);
      });
    });

    it('keeps saved dates for custom ranges', () => {
      expect(
        parsePresetDateRange({
          dateRangeId: 'CUSTOM_DATE_RANGE',
          customDateRange: [
            '2024-01-01T00:00:00.000Z',
            '2024-01-10T00:00:00.000Z',
          ],
        })
      ).toEqual({
        rangeType: 'custom',
        dateRange: [
          new Date('2024-01-01T00:00:00.000Z'),
          new Date('2024-01-10T00:00:00.000Z'),
        ],
      });
    });

    it('returns null when the preset has no usable range', () => {
      expect(parsePresetDateRange({ range: 7 })).toBeNull();
    });
  });

  describe('parsePresetFilters', () => {
    it('falls back to the page filters saved in extra', () => {
      expect(
        parsePresetFilters({
          agentIds: [],
          groupById: '3',
          extra: { user_ids: ['4'], inbox_id: [2], rating: 5 },
        })
      ).toMatchObject({
        range: null,
        groupById: 3,
        businessHours: false,
        timeRange: null,
        agentIds: [4],
        inboxIds: [2],
        teamIds: [],
        labelIds: [],
        ratingValue: 5,
      });
    });
  });

  it('pickByIds keeps the items with matching ids', () => {
    expect(pickByIds([{ id: 1 }, { id: 2 }], ['2'])).toEqual([{ id: 2 }]);
  });

  describe('report URL filters', () => {
    it('serializes the URL query of the report filters', () => {
      expect(
        serializeReportQuery({
          from: String(JAN_1),
          to: String(JAN_10_END),
          range: 'custom',
          business_hours: 'true',
          group_by: '2',
        })
      ).toEqual({
        rangeType: 'custom',
        dateRangeId: 'CUSTOM_DATE_RANGE',
        customDateRange: [
          '2024-01-01T00:00:00.000Z',
          '2024-01-10T23:59:59.000Z',
        ],
        businessHours: true,
        groupById: 2,
      });
    });

    it('builds the URL query for a preset', () => {
      expect(
        buildPresetReportQuery(
          {
            rangeType: 'custom',
            customDateRange: [
              '2024-01-01T00:00:00.000Z',
              '2024-01-10T00:00:00.000Z',
            ],
            businessHours: true,
            groupById: 2,
          },
          {}
        )
      ).toEqual({
        from: JAN_1,
        to: JAN_10_END,
        range: 'custom',
        business_hours: 'true',
        group_by: 2,
      });
    });

    it('keeps the current dates when the preset has no range', () => {
      expect(
        buildPresetReportQuery(
          { businessHours: false },
          { from: String(JAN_1), to: String(JAN_10_END), range: 'custom' }
        )
      ).toEqual({ from: JAN_1, to: JAN_10_END, range: 'custom' });
    });
  });

  describe('SLA URL filters', () => {
    it('serializes the SLA filters from the URL query', () => {
      expect(
        serializeSLAReportQuery({
          from: String(JAN_1),
          to: String(JAN_10_END),
          range: 'custom',
          agent_id: '3',
          sla_policy_id: '9',
          label: 'vip',
        })
      ).toMatchObject({
        rangeType: 'custom',
        agentIds: [3],
        inboxIds: [],
        teamIds: [],
        slaFilters: {
          assigned_agent_id: 3,
          inbox_id: null,
          team_id: null,
          sla_policy_id: 9,
          label_list: 'vip',
        },
      });
    });

    it('builds the SLA URL query from new and old presets', () => {
      const customDateRange = [
        '2024-01-01T00:00:00.000Z',
        '2024-01-10T00:00:00.000Z',
      ];

      expect(
        buildPresetSLAReportQuery(
          {
            dateRangeId: 'CUSTOM_DATE_RANGE',
            customDateRange,
            inboxIds: [5],
            slaFilters: { assigned_agent_id: 3, label_list: 'vip' },
          },
          {}
        )
      ).toEqual({
        from: JAN_1,
        to: JAN_10_END,
        range: 'custom',
        agent_id: 3,
        inbox_id: 5,
        label: 'vip',
      });
    });
  });
});
