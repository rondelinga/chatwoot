<script>
import V4Button from 'dashboard/components-next/button/Button.vue';
import { useAlert, useTrack } from 'dashboard/composables';
import { useRestrictedAgent } from 'dashboard/composables/useRestrictedAgent';
import differenceInDays from 'date-fns/differenceInDays';
import fromUnixTime from 'date-fns/fromUnixTime';
import ReportFilters from './ReportFilters.vue';
import ReportFilterPresets from './ReportFilterPresets.vue';
import ReportContainer from '../ReportContainer.vue';
import { GROUP_BY_FILTER } from '../constants';
import { generateFileName } from '../../../../../helper/downloadHelper';
import { REPORTS_EVENTS } from '../../../../../helper/AnalyticsHelper/events';
import ReportHeader from './ReportHeader.vue';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import { DATE_RANGE_TYPES } from 'dashboard/components/ui/DatePicker/helpers/DatePickerHelper';
import { generateReportURLParams } from '../helpers/reportFilterHelper';
import {
  buildPresetReportQuery,
  parsePresetFilters,
  serializeReportQuery,
} from '../helpers/reportFilterPresetHelper';

export default {
  components: {
    ReportHeader,
    V4Button,
    ReportFilters,
    ReportFilterPresets,
    ReportContainer,
  },
  props: {
    type: {
      type: String,
      default: 'account',
    },
    getterKey: {
      type: String,
      default: '',
    },
    actionKey: {
      type: String,
      default: '',
    },
    downloadButtonLabel: {
      type: String,
      default: 'Download Reports',
    },
    reportTitle: {
      type: String,
      default: 'Download Reports',
    },
    hasBackButton: {
      type: Boolean,
      default: false,
    },
    selectedItem: {
      type: Object,
      default: null,
    },
  },
  setup() {
    const { canExportData } = useRestrictedAgent();

    return { canExportData };
  },
  data() {
    return {
      from: 0,
      to: 0,
      selectedFilter: this.selectedItem,
      groupBy: GROUP_BY_FILTER[1],
      businessHours: false,
      // Remounts ReportFilters so it re-reads the URL after a preset is applied
      filtersKey: 0,
      // ReportFilters reads its range from the URL on mount, so it waits for the default range
      isDefaultRangeReady: false,
    };
  },
  computed: {
    filterType() {
      const pluralMap = {
        agent: 'agents',
        team: 'teams',
        inbox: 'inboxes',
        label: 'labels',
      };
      return pluralMap[this.type] || this.type;
    },
    filterItemsList() {
      return this.$store.getters[this.getterKey] || [];
    },
    isAgentType() {
      return this.type === 'agent';
    },
    selectedFilterId() {
      return this.selectedFilter?.id || null;
    },
    presetFilters() {
      const entityId = Number(this.$route.params.id);
      const entityIds = entityId ? [entityId] : [];
      const idsFor = type => (this.type === type ? entityIds : []);

      return {
        ...serializeReportQuery(this.$route.query),
        groupById: this.groupBy.id,
        agentIds: idsFor('agent'),
        inboxIds: idsFor('inbox'),
        teamIds: idsFor('team'),
        labelIds: idsFor('label'),
      };
    },
    reportKeys() {
      return {
        CONVERSATIONS: 'conversations_count',
        ...(!this.isAgentType && {
          INCOMING_MESSAGES: 'incoming_messages_count',
        }),
        OUTGOING_MESSAGES: 'outgoing_messages_count',
        FIRST_RESPONSE_TIME: 'avg_first_response_time',
        RESOLUTION_TIME: 'avg_resolution_time',
        RESOLUTION_COUNT: 'resolutions_count',
        REPLY_TIME: 'reply_time',
        ...(this.isAgentType && { AGENT_CHAT_DURATION: 'agent_chat_duration' }),
      };
    },
  },
  watch: {
    filterItemsList(items) {
      // Opening the report without an entity id shows the first entity
      if (!this.$route.params.id && items.length) {
        this.$router.replace({
          name: `${this.type}_reports_show`,
          params: { ...this.$route.params, id: items[0].id },
          query: this.$route.query,
        });
      }
    },
  },
  async created() {
    await this.applyDefaultRange();
  },
  mounted() {
    this.$store.dispatch(this.actionKey);
  },
  methods: {
    async applyDefaultRange() {
      // Upstream ReportFilters defaults to the last 7 days; these reports open on today
      const { query } = this.$route;
      if (!query.range && !query.from && !query.to) {
        const today = new Date();
        await this.$router.replace({
          query: {
            ...query,
            ...generateReportURLParams({
              from: getUnixStartOfDay(today),
              to: getUnixEndOfDay(today),
              range: DATE_RANGE_TYPES.TODAY,
            }),
          },
        });
      }
      this.isDefaultRangeReady = true;
    },
    fetchAllData() {
      if (this.selectedFilter) {
        const { from, to, groupBy, businessHours } = this;
        this.$store.dispatch('fetchAccountSummary', {
          from,
          to,
          type: this.type,
          id: this.selectedFilter.id,
          groupBy: groupBy.period,
          businessHours,
        });
        this.fetchChartData();
      }
    },
    fetchChartData() {
      Object.keys(this.reportKeys).forEach(async key => {
        try {
          const { from, to, groupBy, businessHours } = this;
          this.$store.dispatch('fetchAccountReport', {
            metric: this.reportKeys[key],
            from,
            to,
            type: this.type,
            id: this.selectedFilter.id,
            groupBy: groupBy.period,
            businessHours,
          });
        } catch {
          useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
        }
      });
    },
    downloadReports() {
      const { from, to, type, businessHours } = this;
      const dispatchMethods = {
        agent: 'downloadAgentReports',
        label: 'downloadLabelReports',
        inbox: 'downloadInboxReports',
        team: 'downloadTeamReports',
      };
      if (dispatchMethods[type]) {
        const fileName = generateFileName({ type, to, businessHours });
        const params = { from, to, fileName, businessHours };
        this.$store.dispatch(dispatchMethods[type], params);
      }
    },
    async applyPreset(filters) {
      const preset = parsePresetFilters(filters);
      const presetEntityId = {
        agent: preset.agentIds,
        inbox: preset.inboxIds,
        team: preset.teamIds,
        label: preset.labelIds,
      }[this.type][0];
      const entity = this.filterItemsList.find(
        item => item.id === presetEntityId
      );

      await this.$router.replace({
        name: `${this.type}_reports_show`,
        params: {
          ...this.$route.params,
          id: entity?.id ?? this.$route.params.id,
        },
        query: buildPresetReportQuery(filters, this.$route.query),
      });
      this.filtersKey += 1;
    },
    onFilterChange(payload) {
      const { from, to, businessHours, groupBy } = payload;
      if (this.from !== 0 && this.to !== 0) {
        useTrack(REPORTS_EVENTS.FILTER_REPORT, {
          filterValue: { from, to, groupBy, businessHours },
          reportType: this.type,
        });
      }
      this.from = from;
      this.to = to;
      this.businessHours = businessHours;

      if (differenceInDays(fromUnixTime(to), fromUnixTime(from)) === 0) {
        // Single-day ranges are reported hourly
        this.groupBy = GROUP_BY_FILTER[5];
      } else if (groupBy) {
        this.groupBy = groupBy;
      } else {
        this.groupBy = GROUP_BY_FILTER[1];
      }

      // Get filter value directly from filterType key
      const filterValue = payload[this.filterType];
      if (filterValue) {
        this.selectedFilter = Array.isArray(filterValue)
          ? filterValue[0]
          : filterValue;
      } else {
        this.selectedFilter = null;
      }

      this.fetchAllData();
    },
  },
};
</script>

<template>
  <ReportHeader :header-title="reportTitle" :has-back-button="hasBackButton">
    <V4Button
      v-if="canExportData"
      :label="downloadButtonLabel"
      icon="i-ph-download-simple"
      size="sm"
      @click="downloadReports"
    />
  </ReportHeader>

  <ReportFilterPresets
    v-if="filterItemsList"
    class="mb-3"
    :filters="presetFilters"
    @apply="applyPreset"
  />
  <ReportFilters
    v-if="filterItemsList && isDefaultRangeReady"
    :key="filtersKey"
    :filter-type="filterType"
    :selected-item="selectedFilter"
    @filter-change="onFilterChange"
  />
  <ReportContainer
    v-if="filterItemsList.length"
    :group-by="groupBy"
    :report-keys="reportKeys"
    :from="from"
    :to="to"
    :report-type="type"
    :selected-item-id="selectedFilterId"
    :business-hours="businessHours"
  />
</template>
