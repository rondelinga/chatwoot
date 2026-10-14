import {
  DATE_RANGE_TYPES,
  getActiveDateRange,
} from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';
import { GROUP_BY_FILTER } from '../constants';

export const DEFAULT_TIME_RANGE = { since: '00:00', until: '23:59' };

const ALL_GROUP_BY_IDS = [5, 1, 2, 3, 4];

const GROUP_BY_IDS_BY_RANGE = {
  [DATE_RANGE_TYPES.TODAY]: [5],
  [DATE_RANGE_TYPES.LAST_7_DAYS]: [1],
  [DATE_RANGE_TYPES.LAST_30_DAYS]: [1, 2],
  [DATE_RANGE_TYPES.LAST_3_MONTHS]: [1, 2, 3],
  [DATE_RANGE_TYPES.LAST_6_MONTHS]: [2, 3],
  [DATE_RANGE_TYPES.LAST_YEAR]: [2, 3],
};

export const GROUP_BY_TRANSLATION_KEYS = {
  hour: 'REPORT.GROUPING_OPTIONS.HOUR',
  day: 'REPORT.GROUPING_OPTIONS.DAY',
  week: 'REPORT.GROUPING_OPTIONS.WEEK',
  month: 'REPORT.GROUPING_OPTIONS.MONTH',
  year: 'REPORT.GROUPING_OPTIONS.YEAR',
};

// Unix timestamp of the calendar day of `date` at `time` (HH:mm) in UTC.
export const getUnixWithTime = (date, time) => {
  const [hours, minutes] = time.split(':').map(Number);
  return Math.floor(
    Date.UTC(
      date.getFullYear(),
      date.getMonth(),
      date.getDate(),
      hours,
      minutes
    ) / 1000
  );
};

export const getGroupByOptions = rangeType =>
  (GROUP_BY_IDS_BY_RANGE[rangeType] || ALL_GROUP_BY_IDS).map(
    id => GROUP_BY_FILTER[id]
  );

// Keeps the current grouping when the range allows it, otherwise falls back to the first allowed one.
export const resolveGroupBy = (rangeType, current) => {
  const options = getGroupByOptions(rangeType);
  return options.find(option => option.id === current?.id) || options[0];
};

// Preset ranges are recalculated relative to today; custom ranges keep their saved dates.
export const getInitialDateRange = (rangeType, savedDateRange) => {
  if (rangeType === DATE_RANGE_TYPES.CUSTOM_RANGE && savedDateRange) {
    return savedDateRange;
  }
  const { start, end } = getActiveDateRange(rangeType, new Date());
  return [start, end];
};
