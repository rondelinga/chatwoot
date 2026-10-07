<script>
import WootDateRangePicker from 'dashboard/components/ui/DateRangePicker.vue';
import ReportsFiltersDateRange from './Filters/DateRange.vue';
import ReportsFiltersDateGroupBy from './Filters/DateGroupBy.vue';
import ReportsFiltersAgents from './Filters/Agents.vue';
import ReportsFiltersLabels from './Filters/Labels.vue';
import ReportsFiltersInboxes from './Filters/Inboxes.vue';
import ReportsFiltersTeams from './Filters/Teams.vue';
import ReportsFiltersRatings from './Filters/Ratings.vue';
import ReportsFiltersTimeRange from './Filters/TimeRange.vue';
import ReportFilterPresets from './ReportFilterPresets.vue';
import FilterButton from 'dashboard/components/ui/Dropdown/DropdownButton.vue';
import subDays from 'date-fns/subDays';
import { DATE_RANGE_OPTIONS, GROUP_BY_OPTIONS } from '../constants';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';

export default {
  components: {
    WootDateRangePicker,
    ReportsFiltersDateRange,
    ReportsFiltersDateGroupBy,
    ReportsFiltersAgents,
    ReportsFiltersLabels,
    ReportsFiltersInboxes,
    ReportsFiltersTeams,
    ReportsFiltersRatings,
    ReportsFiltersTimeRange,
    ReportFilterPresets,
    FilterButton,
    ToggleSwitch,
  },

  props: {
    showGroupByFilter: Boolean,
    showAgentsFilter: Boolean,
    showLabelsFilter: Boolean,
    showInboxFilter: Boolean,
    showRatingFilter: Boolean,
    showTeamFilter: Boolean,
    showBusinessHoursSwitch: {
      type: Boolean,
      default: true,
    },
    showTimeRangeFilter: Boolean,
    section: {
      type: String,
      default: '',
    },
    extraFilters: {
      type: Object,
      default: () => ({}),
    },
  },

  emits: ['filterChange', 'applyExtraFilters'],

  data() {
    const saved = this.$store.getters.getReportFilters;

    const initialDateRange =
      saved.selectedDateRange || DATE_RANGE_OPTIONS.TODAY;

    let initialGroupBy = saved.selectedGroupByFilter || null;

    if (!initialGroupBy) {
      if (
        initialDateRange.groupByOptions &&
        initialDateRange.groupByOptions.length > 0
      ) {
        if (initialDateRange.id === DATE_RANGE_OPTIONS.TODAY.id) {
          const hourOption = initialDateRange.groupByOptions.find(
            opt => opt.period === 'hour'
          );
          initialGroupBy = hourOption || initialDateRange.groupByOptions[0];
        } else {
          initialGroupBy = initialDateRange.groupByOptions[0];
        }
      }
    }

    return {
      selectedDateRange: initialDateRange,
      selectedGroupByFilter: initialGroupBy,
      selectedLabel: saved.selectedLabel || null,
      selectedInbox: saved.selectedInbox || [],
      selectedTeam: saved.selectedTeam || [],
      selectedRating: saved.selectedRating || null,
      selectedAgents: saved.selectedAgents || [],
      customDateRange: saved.customDateRange || [new Date(), new Date()],
      businessHoursSelected: saved.businessHoursSelected ?? false,
      selectedTimeRange: saved.selectedTimeRange || {
        since: '00:00',
        until: '23:59',
      },
    };
  },

  computed: {
    isDateRangeSelected() {
      return (
        this.selectedDateRange.id === DATE_RANGE_OPTIONS.CUSTOM_DATE_RANGE.id
      );
    },

    isTodaySelected() {
      return this.selectedDateRange.id === DATE_RANGE_OPTIONS.TODAY.id;
    },

    isGroupByPossible() {
      return !this.isTodaySelected;
    },

    validGroupOptions() {
      if (this.isTodaySelected) {
        return [GROUP_BY_OPTIONS.HOUR];
      }
      return this.selectedDateRange.groupByOptions || [];
    },

    validGroupBy() {
      if (!this.validGroupOptions || !this.validGroupOptions.length) {
        return null;
      }
      if (!this.selectedGroupByFilter) {
        if (this.selectedDateRange.id === DATE_RANGE_OPTIONS.TODAY.id) {
          const hourOption = this.validGroupOptions.find(
            opt => opt.period === 'hour'
          );
          return hourOption || this.validGroupOptions[0];
        }
        return this.validGroupOptions[0];
      }

      const validIds = this.validGroupOptions.map(opt => opt.id);
      return validIds.includes(this.selectedGroupByFilter.id)
        ? this.selectedGroupByFilter
        : this.validGroupOptions[0];
    },

    hasOtherFilters() {
      return (
        this.showAgentsFilter ||
        this.showLabelsFilter ||
        this.showTeamFilter ||
        this.showInboxFilter ||
        this.showRatingFilter
      );
    },

    hasClearableFilters() {
      const hasItems = value =>
        Array.isArray(value) ? value.length > 0 : Boolean(value);

      return (
        hasItems(this.selectedAgents) ||
        hasItems(this.selectedInbox) ||
        hasItems(this.selectedTeam) ||
        hasItems(this.selectedLabel) ||
        this.selectedRating != null
      );
    },

    serializedFilters() {
      const extra = this.extraFilters || {};

      return {
        dateRangeId: this.selectedDateRange?.id || null,
        customDateRange: this.isoDates(this.customDateRange),
        groupById: this.selectedGroupByFilter?.id || null,
        businessHours: this.businessHoursSelected,
        timeRange: this.selectedTimeRange,
        agentIds: this.firstIds(
          this.idsOf(this.selectedAgents),
          extra.agentIds,
          extra.user_ids
        ),
        inboxIds: this.firstIds(
          this.idsOf(this.selectedInbox),
          extra.inboxIds,
          extra.inbox_id
        ),
        teamIds: this.firstIds(
          this.idsOf(this.selectedTeam),
          extra.teamIds,
          extra.team_id
        ),
        labelIds: this.firstIds(
          this.idsOf(
            Array.isArray(this.selectedLabel) ? this.selectedLabel : []
          ),
          extra.labelIds
        ),
        ratingValue: this.selectedRating?.value ?? extra.rating ?? null,
        extra,
      };
    },
  },

  mounted() {
    this.emitChange();
  },

  methods: {
    getUnixWithTime(date, time) {
      const [hours, minutes] = time.split(':').map(Number);

      const year = date.getFullYear();
      const month = date.getMonth();
      const day = date.getDate();

      const utcDate = new Date(
        Date.UTC(year, month, day, hours, minutes, 0, 0)
      );

      return Math.floor(utcDate.getTime() / 1000);
    },

    emitChange() {
      const startDate = this.isDateRangeSelected
        ? this.customDateRange[0]
        : subDays(new Date(), this.selectedDateRange.offset || 0);

      const endDate = this.isDateRangeSelected
        ? this.customDateRange[1]
        : new Date();

      const from = this.getUnixWithTime(
        startDate,
        this.selectedTimeRange.since
      );

      const to = this.getUnixWithTime(endDate, this.selectedTimeRange.until);

      this.$store.dispatch('updateReportFilters', {
        selectedDateRange: this.selectedDateRange,
        selectedGroupByFilter: this.selectedGroupByFilter,
        customDateRange: this.customDateRange,
        businessHoursSelected: this.businessHoursSelected,
        selectedAgents: this.selectedAgents,
        selectedLabel: this.selectedLabel,
        selectedInbox: this.selectedInbox,
        selectedTeam: this.selectedTeam,
        selectedRating: this.selectedRating,
        selectedTimeRange: this.selectedTimeRange,
      });

      this.$emit('filterChange', {
        from,
        to,
        groupBy: this.selectedGroupByFilter,
        businessHours: this.businessHoursSelected,
        selectedAgents: this.selectedAgents,
        selectedLabel: this.selectedLabel,
        selectedInbox: this.selectedInbox,
        selectedTeam: this.selectedTeam,
        selectedRating: this.selectedRating,
        timeRange: this.selectedTimeRange,
      });
    },

    onDateRangeChange(selectedRange) {
      this.selectedDateRange = selectedRange;

      if (selectedRange.id === DATE_RANGE_OPTIONS.TODAY.id) {
        if (this.validGroupOptions && this.validGroupOptions.length) {
          const hourOption = this.validGroupOptions.find(
            opt => opt.period === 'hour'
          );
          if (hourOption) {
            this.selectedGroupByFilter = hourOption;
          }
        }
      } else {
        this.selectedGroupByFilter = this.validGroupBy;
      }

      this.emitChange();
    },

    onCustomDateRangeChange(value) {
      this.customDateRange = value;
      this.selectedGroupByFilter = this.validGroupBy;
      this.emitChange();
    },

    onGroupingChange(payload) {
      this.selectedGroupByFilter = payload;
      this.emitChange();
    },

    handleAgentsFilterSelection(selectedAgents) {
      this.selectedAgents = selectedAgents;
      this.emitChange();
    },

    handleLabelsFilterSelection(selectedLabels) {
      this.selectedLabel = selectedLabels;
      this.emitChange();
    },

    handleInboxFilterSelection(selectedInbox) {
      this.selectedInbox = selectedInbox;
      this.emitChange();
    },

    handleTeamFilterSelection(selectedTeam) {
      this.selectedTeam = selectedTeam;
      this.emitChange();
    },

    handleRatingFilterSelection(selectedRating) {
      this.selectedRating = selectedRating;
      this.emitChange();
    },

    handleTimeRangeChange(timeRange) {
      this.selectedTimeRange = timeRange;
      this.emitChange();
    },

    clearAllFilters() {
      this.selectedAgents = [];
      this.selectedInbox = [];
      this.selectedTeam = [];
      this.selectedLabel = [];
      this.selectedRating = null;
      this.emitChange();
    },

    idsOf(items) {
      return (items || []).map(item => item.id);
    },

    firstIds(...candidates) {
      return candidates.find(ids => Array.isArray(ids) && ids.length) || [];
    },

    isoDates(dates) {
      return (dates || []).map(value =>
        value instanceof Date ? value.toISOString() : value
      );
    },

    pickByIds(items, ids) {
      const selectedIds = new Set((ids || []).map(id => Number(id)));
      return (items || []).filter(item => selectedIds.has(Number(item.id)));
    },

    async applyPreset(filters = {}) {
      const range = Object.values(DATE_RANGE_OPTIONS).find(
        item => item.id === filters.dateRangeId
      );
      if (range) this.selectedDateRange = range;

      if (filters.customDateRange?.length >= 2) {
        this.customDateRange = filters.customDateRange.map(value => {
          const date = new Date(value);
          return Number.isNaN(date.getTime()) ? value : date;
        });
      }

      const groupBy = Object.values(GROUP_BY_OPTIONS).find(
        item => item.id === filters.groupById
      );
      if (groupBy) this.selectedGroupByFilter = groupBy;

      this.businessHoursSelected = Boolean(filters.businessHours);
      if (filters.timeRange?.since && filters.timeRange?.until) {
        this.selectedTimeRange = { ...filters.timeRange };
      }

      await Promise.all([
        this.$store.dispatch('agents/get'),
        this.$store.dispatch('inboxes/get'),
        this.$store.dispatch('teams/get'),
        this.$store.dispatch('labels/get'),
      ]);

      const agents = this.$store.getters['agents/getAgents'] || [];
      const inboxes = this.$store.getters['inboxes/getInboxes'] || [];
      const teams = this.$store.getters['teams/getTeams'] || [];
      const labels = this.$store.getters['labels/getLabels'] || [];
      const extra = filters.extra || {};
      const agentIds = this.firstIds(
        filters.agentIds,
        extra.agentIds,
        extra.user_ids
      );
      const inboxIds = this.firstIds(
        filters.inboxIds,
        extra.inboxIds,
        extra.inbox_id
      );
      const teamIds = this.firstIds(
        filters.teamIds,
        extra.teamIds,
        extra.team_id
      );
      const labelIds = this.firstIds(filters.labelIds, extra.labelIds);

      if (!range && filters.dateFrom && filters.dateTo) {
        this.selectedDateRange = DATE_RANGE_OPTIONS.CUSTOM_DATE_RANGE;
        this.customDateRange = [
          new Date(filters.dateFrom),
          new Date(filters.dateTo),
        ];
      }

      this.selectedAgents = this.pickByIds(agents, agentIds);
      this.selectedInbox = this.pickByIds(inboxes, inboxIds);
      this.selectedTeam = this.pickByIds(teams, teamIds);
      this.selectedLabel = this.pickByIds(labels, labelIds);
      this.selectedRating =
        (filters.ratingValue ?? extra.rating ?? null) == null
          ? null
          : { value: filters.ratingValue ?? extra.rating };

      this.$emit('applyExtraFilters', {
        ...extra,
        user_ids: agentIds,
        inbox_id: inboxIds,
        team_id: teamIds,
        agentIds,
        inboxIds,
        teamIds,
        rating: filters.ratingValue ?? extra.rating ?? null,
        agents: this.pickByIds(agents, agentIds),
        inboxes: this.pickByIds(inboxes, inboxIds),
        teams: this.pickByIds(teams, teamIds),
      });

      this.$nextTick(() => {
        this.emitChange();
      });
    },
  },
};
</script>

<template>
  <div class="flex flex-col gap-3">
    <ReportFilterPresets
      v-if="section"
      :filters="serializedFilters"
      @apply="applyPreset"
    />
    <div class="flex flex-col justify-between gap-3 md:flex-row">
      <div
        class="w-full grid gap-y-2 gap-x-1.5 grid-cols-[repeat(auto-fill,minmax(250px,1fr))]"
      >
        <ReportsFiltersDateRange
          :selected-range="selectedDateRange"
          @on-range-change="onDateRangeChange"
        />

        <WootDateRangePicker
          v-if="isDateRangeSelected"
          show-range
          class="no-margin auto-width"
          :value="customDateRange"
          :confirm-text="$t('REPORT.CUSTOM_DATE_RANGE.CONFIRM')"
          :placeholder="$t('REPORT.CUSTOM_DATE_RANGE.PLACEHOLDER')"
          @change="onCustomDateRangeChange"
        />

        <ReportsFiltersDateGroupBy
          v-if="showGroupByFilter && isGroupByPossible"
          :valid-group-options="validGroupOptions"
          :selected-option="selectedGroupByFilter"
          :selected-date-range="selectedDateRange"
          @on-grouping-change="onGroupingChange"
        />

        <ReportsFiltersTimeRange
          v-if="showTimeRangeFilter"
          :selected-time-range="selectedTimeRange"
          @time-range-changed="handleTimeRangeChange"
        />
      </div>

      <div v-if="showBusinessHoursSwitch" class="flex items-center">
        <span class="mx-2 text-sm whitespace-nowrap">
          {{ $t('REPORT.BUSINESS_HOURS') }}
        </span>
        <ToggleSwitch v-model="businessHoursSelected" @change="emitChange" />
      </div>
    </div>

    <div
      v-if="hasOtherFilters"
      class="w-full grid gap-y-2 gap-x-1.5 grid-cols-[repeat(auto-fill,minmax(250px,1fr))]"
    >
      <ReportsFiltersAgents
        v-if="showAgentsFilter"
        :selected-agents="selectedAgents"
        @agents-filter-selection="handleAgentsFilterSelection"
      />

      <ReportsFiltersLabels
        v-if="showLabelsFilter"
        :selected-label="selectedLabel"
        @labels-filter-selection="handleLabelsFilterSelection"
      />

      <ReportsFiltersInboxes
        v-if="showInboxFilter"
        :selected-inbox="selectedInbox"
        @inbox-filter-selection="handleInboxFilterSelection"
      />

      <ReportsFiltersTeams
        v-if="showTeamFilter"
        :selected-team="selectedTeam"
        @team-filter-selection="handleTeamFilterSelection"
      />

      <ReportsFiltersRatings
        v-if="showRatingFilter"
        :selected-raiting="selectedRating"
        @rating-filter-selection="handleRatingFilterSelection"
      />

      <div v-if="hasClearableFilters" class="flex items-center">
        <FilterButton
          :button-text="$t('REPORT.FILTER_ACTIONS.CLEAR_ALL')"
          @click="clearAllFilters"
        />
      </div>
    </div>
  </div>
</template>
