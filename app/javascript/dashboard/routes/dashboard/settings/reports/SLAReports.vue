<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import SLAMetrics from './components/SLA/SLAMetrics.vue';
import SLATable from './components/SLA/SLATable.vue';
import SLAReportFilters from './components/SLA/SLAReportFilters.vue';
import ReportFilterPresets from './components/ReportFilterPresets.vue';
import { generateFileName } from 'dashboard/helper/downloadHelper';
import ReportHeader from './components/ReportHeader.vue';
import DownloadDropdown from 'dashboard/components/DownloadDropdown.vue';
import { useReportDownloadOptions } from 'dashboard/composables/useReportDownloadOptions';
import {
  parseFilterURLParams,
  parseReportURLParams,
} from './helpers/reportFilterHelper';
import {
  buildPresetSLAReportQuery,
  serializeSLAReportQuery,
} from './helpers/reportFilterPresetHelper';

export default {
  name: 'SLAReports',
  components: {
    DownloadDropdown,
    ReportHeader,
    SLAMetrics,
    SLATable,
    SLAReportFilters,
    ReportFilterPresets,
  },
  setup() {
    const { downloadOptions } = useReportDownloadOptions();
    return { downloadOptions };
  },
  data() {
    return {
      pageNumber: 1,
      activeFilter: {
        from: 0,
        to: 0,
        assigned_agent_id: null,
        inbox_id: null,
        team_id: null,
        sla_policy_id: null,
        label_list: null,
      },
      // Remounts SLAReportFilters so it re-reads the URL after a preset is applied
      filtersKey: 0,
    };
  },
  computed: {
    ...mapGetters({
      slaReports: 'slaReports/getAll',
      slaMetrics: 'slaReports/getMetrics',
      slaMeta: 'slaReports/getMeta',
      uiFlags: 'slaReports/getUIFlags',
    }),
    presetFilters() {
      return serializeSLAReportQuery(this.$route.query);
    },
  },
  mounted() {
    this.$store.dispatch('agents/get');
    this.$store.dispatch('inboxes/get');
    this.$store.dispatch('teams/get');
    this.$store.dispatch('labels/get');
    this.$store.dispatch('sla/get');
    this.fetchSLAMetrics();
    this.fetchSLAReports();
  },
  methods: {
    fetchSLAReports({ pageNumber } = {}) {
      this.$store.dispatch('slaReports/get', {
        page: pageNumber || this.pageNumber,
        ...this.activeFilter,
      });
    },
    fetchSLAMetrics() {
      this.$store.dispatch('slaReports/getMetrics', this.activeFilter);
    },
    onPageChange(pageNumber) {
      this.fetchSLAReports({ pageNumber });
    },
    onFilterChange(params) {
      this.activeFilter = params;
      this.fetchSLAReports();
      this.fetchSLAMetrics();
    },
    async applyPreset(filters) {
      const query = buildPresetSLAReportQuery(filters, this.$route.query);
      await this.$router.replace({ query });
      this.filtersKey += 1;

      // SLAFilter re-emits on mount only when one of its filters is active
      const hasSLAFilters = Object.values(parseFilterURLParams(query)).some(
        Boolean
      );
      if (!hasSLAFilters) {
        const { from, to } = parseReportURLParams(query);
        this.onFilterChange({ from, to });
      }
    },
    downloadReports(option) {
      const type = 'sla';
      const format = option?.value || option || 'csv';
      try {
        this.$store.dispatch('slaReports/download', {
          format,
          fileName: generateFileName({
            type,
            to: this.activeFilter.to,
            format,
          }),
          ...this.activeFilter,
        });
      } catch (error) {
        useAlert(this.$t('SLA_REPORTS.DOWNLOAD_FAILED'));
      }
    },
  },
};
</script>

<template>
  <ReportHeader :header-title="$t('SLA_REPORTS.HEADER')">
    <DownloadDropdown
      :label="$t('SLA_REPORTS.DOWNLOAD_SLA_REPORTS')"
      :options="downloadOptions"
      @select="downloadReports"
    />
  </ReportHeader>
  <div class="flex flex-col flex-1 gap-6">
    <div class="flex flex-col gap-3">
      <ReportFilterPresets :filters="presetFilters" @apply="applyPreset" />
      <SLAReportFilters :key="filtersKey" @filter-change="onFilterChange" />
    </div>
    <SLAMetrics
      :hit-rate="slaMetrics.hitRate"
      :no-of-breaches="slaMetrics.numberOfSLAMisses"
      :no-of-conversations="slaMetrics.numberOfConversations"
      :is-loading="uiFlags.isFetchingMetrics"
    />
    <SLATable
      :sla-reports="slaReports"
      :is-loading="uiFlags.isFetching"
      :current-page="Number(slaMeta.currentPage)"
      :total-count="Number(slaMeta.count)"
      @page-change="onPageChange"
    />
  </div>
</template>
