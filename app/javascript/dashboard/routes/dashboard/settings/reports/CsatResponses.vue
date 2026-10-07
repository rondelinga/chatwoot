<script>
import { mapGetters } from 'vuex';
import { useAlert, useTrack } from 'dashboard/composables';
import CsatMetrics from './components/CsatMetrics.vue';
import CsatTable from './components/CsatTable.vue';
import CsatFilters from './components/Csat/CsatFilters.vue';
import { generateFileName } from '../../../../helper/downloadHelper';
import { REPORTS_EVENTS } from '../../../../helper/AnalyticsHelper/events';
import { FEATURE_FLAGS } from '../../../../featureFlags';
import ReportHeader from './components/ReportHeader.vue';
import DownloadDropdown from 'dashboard/components/DownloadDropdown.vue';
import { useReportDownloadOptions } from 'dashboard/composables/useReportDownloadOptions';

export default {
  name: 'CsatResponses',
  components: {
    CsatMetrics,
    CsatTable,
    CsatFilters,
    ReportHeader,
    DownloadDropdown,
  },
  setup() {
    const { downloadOptions } = useReportDownloadOptions();
    return { downloadOptions };
  },
  data() {
    return {
      pageIndex: 0,
      from: 0,
      to: 0,
      userIds: [],
      inboxIds: [],
      teamIds: [],
      rating: null,
      excludedLabels: [],
      timeRange: {
        since: '00:00',
        until: '23:59',
      },
    };
  },
  computed: {
    ...mapGetters({
      accountId: 'getCurrentAccountId',
      isFeatureEnabledOnAccount: 'accounts/isFeatureEnabledonAccount',
      csatMetrics: 'csat/getMetrics',
    }),
    requestPayload() {
      return {
        from: this.from,
        to: this.to,
        user_ids: this.userIds,
        inbox_ids: this.inboxIds,
        team_ids: this.teamIds,
        rating: this.rating,
        excluded_labels: this.excludedLabels,
        timeRange: this.timeRange,
      };
    },
    isTeamsEnabled() {
      return this.isFeatureEnabledOnAccount(
        this.accountId,
        FEATURE_FLAGS.TEAM_MANAGEMENT
      );
    },
  },
  methods: {
    getAllData() {
      try {
        this.$store.dispatch('csat/getMetrics', this.requestPayload);
        this.getResponses();
      } catch {
        useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
      }
    },
    getResponses() {
      this.$store.dispatch('csat/get', {
        page: this.pageIndex + 1,
        ...this.requestPayload,
      });
    },
    downloadReports(option) {
      const type = 'csat';
      const format = option?.value || option || 'csv';
      try {
        this.$store.dispatch('csat/downloadCSATReports', {
          format,
          fileName: generateFileName({ type, to: this.to, format }),
          ...this.requestPayload,
        });
      } catch (error) {
        useAlert(this.$t('REPORT.CSAT_REPORTS.DOWNLOAD_FAILED'));
      }
    },
    onPageNumberChange(pageIndex) {
      this.pageIndex = pageIndex;
      this.getResponses();
    },
    onFilterChange({
      from,
      to,
      selectedAgents,
      selectedInboxes,
      selectedTeams,
      selectedRating,
      excludedLabels,
      timeRange,
    }) {
      // do not track filter change on initial load
      if (this.from !== 0 && this.to !== 0) {
        useTrack(REPORTS_EVENTS.FILTER_REPORT, {
          filterType: 'date',
          reportType: 'csat',
        });
      }

      this.from = from;
      this.to = to;

      const normalizeArray = value => {
        if (Array.isArray(value)) {
          return value;
        }
        if (value) {
          return [value];
        }
        return [];
      };

      this.userIds = normalizeArray(selectedAgents).map(el => el.id);
      this.inboxIds = normalizeArray(selectedInboxes).map(el => el.id);
      this.teamIds = normalizeArray(selectedTeams).map(el => el.id);
      this.rating = selectedRating?.value ?? null;
      this.excludedLabels = Array.isArray(excludedLabels) ? excludedLabels : [];
      if (timeRange) this.timeRange = timeRange;

      this.getAllData();
    },
  },
};
</script>

<template>
  <ReportHeader :header-title="$t('CSAT_REPORTS.HEADER')">
    <DownloadDropdown
      :label="$t('CSAT_REPORTS.DOWNLOAD')"
      :options="downloadOptions"
      @select="downloadReports"
    />
  </ReportHeader>

  <div class="flex flex-col gap-6">
    <CsatFilters
      :show-team-filter="isTeamsEnabled"
      @filter-change="onFilterChange"
    />
    <div
      v-if="excludedLabels.length"
      class="flex flex-wrap items-center gap-x-3 gap-y-1 px-4 py-3 text-sm rounded-xl bg-n-amber-3 text-n-amber-11"
    >
      <span class="i-lucide-triangle-alert size-4 shrink-0" />
      <span>
        {{
          $t('CSAT_REPORTS.EXCLUSIONS.BANNER', {
            tags: excludedLabels.join(', '),
          })
        }}
      </span>
      <span>
        {{
          $t('CSAT_REPORTS.EXCLUSIONS.SHOWN', {
            shown: csatMetrics.totalResponseCount,
            total: csatMetrics.totalCountBeforeExclusion,
          })
        }}
      </span>
    </div>
    <CsatMetrics :filters="requestPayload" />
    <CsatTable :page-index="pageIndex" @page-change="onPageNumberChange" />
  </div>
</template>
