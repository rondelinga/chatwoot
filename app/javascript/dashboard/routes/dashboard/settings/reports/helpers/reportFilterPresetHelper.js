import fromUnixTime from 'date-fns/fromUnixTime';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import {
  DATE_RANGE_TYPES,
  getActiveDateRange,
} from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';
import {
  generateCompleteURLParams,
  generateReportURLParams,
  parseFilterURLParams,
  parseReportURLParams,
} from './reportFilterHelper';

// Presets saved by the previous report filters (and read by monitor presets) identify ranges by these ids
const RANGE_TYPE_BY_PRESET_RANGE_ID = {
  TODAY: DATE_RANGE_TYPES.TODAY,
  LAST_7_DAYS: DATE_RANGE_TYPES.LAST_7_DAYS,
  LAST_30_DAYS: DATE_RANGE_TYPES.LAST_30_DAYS,
  LAST_3_MONTHS: DATE_RANGE_TYPES.LAST_3_MONTHS,
  LAST_6_MONTHS: DATE_RANGE_TYPES.LAST_6_MONTHS,
  LAST_YEAR: DATE_RANGE_TYPES.LAST_YEAR,
  CUSTOM_DATE_RANGE: DATE_RANGE_TYPES.CUSTOM_RANGE,
};

const PRESET_RANGE_ID_BY_RANGE_TYPE = Object.fromEntries(
  Object.entries(RANGE_TYPE_BY_PRESET_RANGE_ID).map(([id, type]) => [type, id])
);

const toDate = value => {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

export const firstIds = (...candidates) =>
  (candidates.find(ids => Array.isArray(ids) && ids.length) || []).map(Number);

export const idsOf = items => (items || []).map(item => item.id);

export const pickByIds = (items, ids) => {
  const selectedIds = new Set((ids || []).map(Number));
  return (items || []).filter(item => selectedIds.has(Number(item.id)));
};

export const serializePresetDateRange = (rangeType, dateRange) => ({
  rangeType,
  dateRangeId: PRESET_RANGE_ID_BY_RANGE_TYPE[rangeType] || null,
  customDateRange: dateRange.map(value =>
    value instanceof Date ? value.toISOString() : value
  ),
});

// Preset ranges are recalculated relative to today; custom ranges keep their saved dates.
export const parsePresetDateRange = (filters = {}) => {
  const rangeType = Object.values(DATE_RANGE_TYPES).includes(filters.rangeType)
    ? filters.rangeType
    : RANGE_TYPE_BY_PRESET_RANGE_ID[filters.dateRangeId];

  if (rangeType && rangeType !== DATE_RANGE_TYPES.CUSTOM_RANGE) {
    const { start, end } = getActiveDateRange(rangeType, new Date());
    return { rangeType, dateRange: [start, end] };
  }

  const savedDates =
    filters.customDateRange?.length >= 2
      ? filters.customDateRange
      : [filters.dateFrom, filters.dateTo];
  const [start, end] = savedDates.map(toDate);
  if (!start || !end) return null;

  return { rangeType: DATE_RANGE_TYPES.CUSTOM_RANGE, dateRange: [start, end] };
};

export const parsePresetFilters = (filters = {}) => {
  const extra = filters.extra || {};
  const { since, until } = filters.timeRange || {};

  return {
    range: parsePresetDateRange(filters),
    groupById: Number(filters.groupById) || null,
    businessHours: Boolean(filters.businessHours),
    timeRange: since && until ? { since, until } : null,
    agentIds: firstIds(filters.agentIds, extra.agentIds, extra.user_ids),
    inboxIds: firstIds(filters.inboxIds, extra.inboxIds, extra.inbox_id),
    teamIds: firstIds(filters.teamIds, extra.teamIds, extra.team_id),
    labelIds: firstIds(filters.labelIds, extra.labelIds),
    ratingValue: filters.ratingValue ?? extra.rating ?? null,
    extra,
  };
};

const serializeReportQueryRange = query => {
  const { from, to, range } = parseReportURLParams(query);
  if (!from || !to) return {};

  return serializePresetDateRange(range || DATE_RANGE_TYPES.CUSTOM_RANGE, [
    fromUnixTime(from),
    fromUnixTime(to),
  ]);
};

// Date params for URL driven report filters, falling back to the current ones when the preset has no range
const presetDateQuery = (range, currentQuery) => {
  if (!range) {
    const { from, to, range: rangeType } = parseReportURLParams(currentQuery);
    return { from, to, range: rangeType };
  }

  return {
    from: getUnixStartOfDay(range.dateRange[0]),
    to: getUnixEndOfDay(range.dateRange[1]),
    range: range.rangeType,
  };
};

export const serializeReportQuery = query => {
  const { businessHours, groupBy } = parseReportURLParams(query);
  return {
    ...serializeReportQueryRange(query),
    businessHours,
    groupById: groupBy,
  };
};

export const buildPresetReportQuery = (filters, currentQuery) => {
  const { range, businessHours, groupById } = parsePresetFilters(filters);
  return generateReportURLParams({
    ...presetDateQuery(range, currentQuery),
    businessHours,
    groupBy: groupById,
  });
};

export const serializeSLAReportQuery = query => {
  const { agent_id, inbox_id, team_id, sla_policy_id, label } =
    parseFilterURLParams(query);

  return {
    ...serializeReportQueryRange(query),
    agentIds: agent_id ? [agent_id] : [],
    inboxIds: inbox_id ? [inbox_id] : [],
    teamIds: team_id ? [team_id] : [],
    slaFilters: {
      assigned_agent_id: agent_id,
      inbox_id,
      team_id,
      sla_policy_id,
      label_list: label,
    },
  };
};

export const buildPresetSLAReportQuery = (filters, currentQuery) => {
  const { range, agentIds, inboxIds, teamIds } = parsePresetFilters(filters);
  const slaFilters = filters.slaFilters || {};

  return generateCompleteURLParams({
    ...presetDateQuery(range, currentQuery),
    filters: {
      agent_id: slaFilters.assigned_agent_id || agentIds[0],
      inbox_id: slaFilters.inbox_id || inboxIds[0],
      team_id: slaFilters.team_id || teamIds[0],
      sla_policy_id: slaFilters.sla_policy_id,
      label: slaFilters.label_list,
    },
  });
};
