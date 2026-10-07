<script>
import SLAFilter from '../SLA/SLAFilter.vue';
import ReportFilterPresets from '../ReportFilterPresets.vue';
import subDays from 'date-fns/subDays';
import { DATE_RANGE_OPTIONS } from '../../constants';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';

const EMPTY_SLA_FILTERS = {
  assigned_agent_id: null,
  inbox_id: null,
  team_id: null,
  sla_policy_id: null,
  label_list: null,
};

export default {
  components: {
    SLAFilter,
    ReportFilterPresets,
  },
  emits: ['filterChange'],

  data() {
    return {
      selectedDateRange: DATE_RANGE_OPTIONS.LAST_7_DAYS,
      selectedGroupByFilter: null,
      customDateRange: [subDays(new Date(), 6), new Date()],
      slaAppliedFilters: { ...EMPTY_SLA_FILTERS },
    };
  },
  computed: {
    to() {
      return getUnixEndOfDay(this.customDateRange[1]);
    },
    from() {
      return getUnixStartOfDay(this.customDateRange[0]);
    },
    presetFilters() {
      const [start, end, rangeType] = this.customDateRange;
      const {
        assigned_agent_id: agentId,
        inbox_id: inboxId,
        team_id: teamId,
      } = this.slaAppliedFilters;

      return {
        dateRangeId: 'CUSTOM_DATE_RANGE',
        customDateRange: [start, end]
          .filter(Boolean)
          .map(value => (value instanceof Date ? value.toISOString() : value)),
        dateFrom: start instanceof Date ? start.toISOString() : start,
        dateTo: end instanceof Date ? end.toISOString() : end,
        rangeType: typeof rangeType === 'string' ? rangeType : null,
        agentIds: agentId ? [agentId] : [],
        inboxIds: inboxId ? [inboxId] : [],
        teamIds: teamId ? [teamId] : [],
        slaFilters: this.slaAppliedFilters,
      };
    },
  },
  watch: {
    businessHoursSelected() {
      this.emitChange();
    },
  },
  mounted() {
    this.setInitialRange();
  },
  methods: {
    setInitialRange() {
      const { offset } = this.selectedDateRange;
      const fromDate = subDays(new Date(), offset);
      const from = getUnixStartOfDay(fromDate);
      const to = getUnixEndOfDay(new Date());
      this.$emit('filterChange', {
        from,
        to,
        ...this.selectedGroupByFilter,
      });
    },
    emitChange() {
      const { from, to } = this;
      this.$emit('filterChange', {
        from,
        to,
        ...this.selectedGroupByFilter,
      });
    },
    emitFilterChange(params) {
      this.selectedGroupByFilter = params;
      this.slaAppliedFilters = { ...EMPTY_SLA_FILTERS, ...params };
      this.emitChange();
    },
    applyPreset(filters = {}) {
      const range = Object.values(DATE_RANGE_OPTIONS).find(
        item => item.id === filters.dateRangeId
      );
      let start = new Date(filters.dateFrom);
      let end = new Date(filters.dateTo);

      if (range && range.id !== DATE_RANGE_OPTIONS.CUSTOM_DATE_RANGE.id) {
        start = subDays(new Date(), range.offset || 0);
        end = new Date();
      } else if (filters.customDateRange?.length >= 2) {
        start = new Date(filters.customDateRange[0]);
        end = new Date(filters.customDateRange[1]);
      }

      if (!Number.isNaN(start.getTime()) && !Number.isNaN(end.getTime())) {
        this.customDateRange = filters.rangeType
          ? [start, end, filters.rangeType]
          : [start, end];
      }

      const savedSlaFilters = filters.slaFilters || {};
      const slaFilters = {
        ...EMPTY_SLA_FILTERS,
        ...savedSlaFilters,
        assigned_agent_id:
          savedSlaFilters.assigned_agent_id || filters.agentIds?.[0] || null,
        inbox_id: savedSlaFilters.inbox_id || filters.inboxIds?.[0] || null,
        team_id: savedSlaFilters.team_id || filters.teamIds?.[0] || null,
      };
      this.slaAppliedFilters = slaFilters;
      this.selectedGroupByFilter = slaFilters;
      this.$refs.slaFilter?.applySavedFilters(slaFilters);
      this.emitChange();
    },
    onDateRangeChange(value) {
      this.customDateRange = value;
      this.emitChange();
    },
  },
};
</script>

<template>
  <div class="flex flex-col w-full gap-3">
    <ReportFilterPresets :filters="presetFilters" @apply="applyPreset" />
    <div class="flex flex-col flex-wrap w-full gap-3 md:flex-row">
      <woot-date-picker
        v-model:date-range="customDateRange"
        @date-range-changed="onDateRangeChange"
      />
      <SLAFilter ref="slaFilter" @filter-change="emitFilterChange" />
    </div>
  </div>
</template>
