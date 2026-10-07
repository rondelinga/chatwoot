import {
  getUnixWithTime,
  getGroupByOptions,
  resolveGroupBy,
  getInitialDateRange,
} from './advancedReportFilterHelper';
import { GROUP_BY_FILTER } from '../constants';

describe('advancedReportFilterHelper', () => {
  describe('getUnixWithTime', () => {
    it('returns the UTC timestamp of the local calendar day at the given time', () => {
      const date = new Date(2024, 0, 15, 18, 45);

      expect(getUnixWithTime(date, '00:00')).toBe(
        Date.UTC(2024, 0, 15, 0, 0) / 1000
      );
      expect(getUnixWithTime(date, '23:59')).toBe(
        Date.UTC(2024, 0, 15, 23, 59) / 1000
      );
      expect(getUnixWithTime(date, '08:30')).toBe(
        Date.UTC(2024, 0, 15, 8, 30) / 1000
      );
    });
  });

  describe('getGroupByOptions', () => {
    it('allows only hourly grouping for today', () => {
      expect(getGroupByOptions('today')).toEqual([GROUP_BY_FILTER[5]]);
    });

    it('returns the grouping options allowed for preset ranges', () => {
      expect(getGroupByOptions('last7days')).toEqual([GROUP_BY_FILTER[1]]);
      expect(getGroupByOptions('last30days')).toEqual([
        GROUP_BY_FILTER[1],
        GROUP_BY_FILTER[2],
      ]);
      expect(getGroupByOptions('lastYear')).toEqual([
        GROUP_BY_FILTER[2],
        GROUP_BY_FILTER[3],
      ]);
    });

    it('allows every grouping for custom ranges', () => {
      expect(getGroupByOptions('custom')).toEqual([
        GROUP_BY_FILTER[5],
        GROUP_BY_FILTER[1],
        GROUP_BY_FILTER[2],
        GROUP_BY_FILTER[3],
        GROUP_BY_FILTER[4],
      ]);
    });
  });

  describe('resolveGroupBy', () => {
    it('keeps the current grouping when the range allows it', () => {
      expect(resolveGroupBy('last30days', GROUP_BY_FILTER[2])).toEqual(
        GROUP_BY_FILTER[2]
      );
    });

    it('falls back to the first allowed grouping', () => {
      expect(resolveGroupBy('last6months', GROUP_BY_FILTER[1])).toEqual(
        GROUP_BY_FILTER[2]
      );
      expect(resolveGroupBy('today', null)).toEqual(GROUP_BY_FILTER[5]);
    });
  });

  describe('getInitialDateRange', () => {
    it('keeps saved dates for custom ranges', () => {
      const saved = [new Date(2024, 0, 1), new Date(2024, 0, 10)];
      expect(getInitialDateRange('custom', saved)).toBe(saved);
    });

    it('recalculates preset ranges relative to today', () => {
      const [start, end] = getInitialDateRange('today', [
        new Date(2020, 0, 1),
        new Date(2020, 0, 2),
      ]);
      const today = new Date();

      expect(start.toDateString()).toBe(today.toDateString());
      expect(end.toDateString()).toBe(today.toDateString());
    });
  });
});
