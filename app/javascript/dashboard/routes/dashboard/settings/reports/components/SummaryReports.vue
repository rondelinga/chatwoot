<script setup>
import OverviewReportFilters from './OverviewReportFilters.vue';
import ReportsFiltersAgents from './Filters/Agents.vue';
import ReportsFiltersInboxes from './Filters/Inboxes.vue';
import ReportsFiltersTeams from './Filters/Teams.vue';
import ReportsFiltersLabels from './Filters/Labels.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { formatTime } from '@chatwoot/utils';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Table from 'dashboard/components/table/Table.vue';
import {
  useVueTable,
  createColumnHelper,
  getCoreRowModel,
  getSortedRowModel,
} from '@tanstack/vue-table';
import { computed, onMounted, ref, h } from 'vue';
import ReportsAPI from 'dashboard/api/reports';

const props = defineProps({
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
  summaryKey: {
    type: String,
    default: '',
  },
  fetchItemsKey: {
    type: String,
    required: true,
  },
  showAgentChatDuration: {
    type: Boolean,
    default: false,
  },
  showCsatScore: {
    type: Boolean,
    default: false,
  },
  customHeaderClass: {
    type: String,
    default: '',
  },
  customCellClass: {
    type: String,
    default: '',
  },
});

const store = useStore();

const from = ref(0);
const to = ref(0);
const businessHours = ref(false);
const selectedAgents = ref([]);
const selectedInboxes = ref([]);
const selectedTeams = ref([]);
const selectedLabels = ref([]);
const timeRange = ref({
  since: '00:00',
  until: '23:59',
});
import { useI18n } from 'vue-i18n';
import SummaryReportLink from './SummaryReportLink.vue';

const flagMap = {
  agent: 'isFetchingAgentSummaryReports',
  inbox: 'isFetchingInboxSummaryReports',
  team: 'isFetchingTeamSummaryReports',
  label: 'isFetchingLabelSummaryReports',
};

const uiFlags = useMapGetter('summaryReports/getUIFlags');
const isLoading = computed(() => uiFlags.value[flagMap[props.type]] ?? false);

const rowItems = useMapGetter([props.getterKey]) || [];
const reportMetrics = useMapGetter([props.summaryKey]) || [];

const getMetrics = id =>
  reportMetrics.value.find(metrics => metrics.id === Number(id)) || {};
const columnHelper = createColumnHelper();
const { t } = useI18n();

const defaulSpanRender = cellProps =>
  h(
    'span',
    {
      class: cellProps.getValue() ? '' : 'text-n-slate-12',
    },
    cellProps.getValue()
  );

const parseFormattedValue = value => {
  if (!value || value === '--') return 0;
  if (typeof value === 'string') {
    return parseFloat(value.replace(/,/g, '')) || 0;
  }
  return value;
};

const columns = computed(() => {
  const baseColumns = [
    columnHelper.accessor('name', {
      header: t(`SUMMARY_REPORTS.${props.type.toUpperCase()}`),
      width: 300,
      cell: cellProps =>
        h(SummaryReportLink, {
          ...cellProps,
          class: props.customCellClass || '',
        }),
      enableSorting: true,
    }),
    columnHelper.accessor('conversationsCount', {
      header: t('SUMMARY_REPORTS.CONVERSATIONS'),
      width: 200,
      cell: defaulSpanRender,
      enableSorting: true,
      sortingFn: (rowA, rowB) => {
        const a = parseFormattedValue(rowA.original.conversationsCount);
        const b = parseFormattedValue(rowB.original.conversationsCount);
        return a - b;
      },
    }),
    columnHelper.accessor('avgFirstResponseTime', {
      header: t('SUMMARY_REPORTS.AVG_FIRST_RESPONSE_TIME'),
      width: 200,
      cell: defaulSpanRender,
      enableSorting: true,
      sortingFn: (rowA, rowB) => {
        const a = rowA.original.avgFirstResponseTimeRaw || 0;
        const b = rowB.original.avgFirstResponseTimeRaw || 0;
        return a - b;
      },
    }),
    columnHelper.accessor('avgResolutionTime', {
      header: t('SUMMARY_REPORTS.AVG_RESOLUTION_TIME'),
      width: 200,
      cell: defaulSpanRender,
      enableSorting: true,
      sortingFn: (rowA, rowB) => {
        const a = rowA.original.avgResolutionTimeRaw || 0;
        const b = rowB.original.avgResolutionTimeRaw || 0;
        return a - b;
      },
    }),
    columnHelper.accessor('avgReplyTime', {
      header: t('SUMMARY_REPORTS.AVG_REPLY_TIME'),
      width: 200,
      cell: defaulSpanRender,
      enableSorting: true,
      sortingFn: (rowA, rowB) => {
        const a = rowA.original.avgReplyTimeRaw || 0;
        const b = rowB.original.avgReplyTimeRaw || 0;
        return a - b;
      },
    }),
    columnHelper.accessor('resolutionsCount', {
      header: t('SUMMARY_REPORTS.RESOLUTION_COUNT'),
      width: 200,
      cell: defaulSpanRender,
      enableSorting: true,
      sortingFn: (rowA, rowB) => {
        const a = parseFormattedValue(rowA.original.resolutionsCount);
        const b = parseFormattedValue(rowB.original.resolutionsCount);
        return a - b;
      },
    }),
  ];

  if (props.showAgentChatDuration) {
    baseColumns.push(
      columnHelper.accessor('agentChatDuration', {
        header: t('SUMMARY_REPORTS.AGENT_CHAT_DURATION'),
        width: 220,
        cell: defaulSpanRender,
        enableSorting: true,
        sortingFn: (rowA, rowB) => {
          const a = rowA.original.agentChatDurationRaw || 0;
          const b = rowB.original.agentChatDurationRaw || 0;
          return a - b;
        },
      })
    );
  }

  if (props.showCsatScore) {
    baseColumns.push(
      columnHelper.accessor('csatSatisfactionScore', {
        header: t('SUMMARY_REPORTS.CSAT_SATISFACTION_SCORE'),
        width: 200,
        cell: defaulSpanRender,
        enableSorting: true,
        sortingFn: (rowA, rowB) => {
          const a = rowA.original.csatSatisfactionScoreRaw || 0;
          const b = rowB.original.csatSatisfactionScoreRaw || 0;
          return a - b;
        },
      })
    );
  }

  return baseColumns;
});

const renderAvgTime = value => (value ? formatTime(value) : '--');

const renderCount = value => (value ? value.toLocaleString() : '--');

const renderCsatScore = value => (value ? `${value}%` : '--');

const hasActiveFilters = computed(() => {
  return (
    selectedAgents.value.length > 0 ||
    selectedInboxes.value.length > 0 ||
    selectedTeams.value.length > 0 ||
    selectedLabels.value.length > 0
  );
});

const tableData = computed(() => {
  let filteredRows = rowItems.value;

  if (hasActiveFilters.value) {
    const metricsIds = reportMetrics.value.map(m => m.id);
    filteredRows = rowItems.value.filter(row => metricsIds.includes(row.id));
  }

  return filteredRows.map(row => {
    const rowMetrics = getMetrics(row.id);

    const {
      conversationsCount,
      avgFirstResponseTime,
      avgResolutionTime,
      avgReplyTime,
      resolvedConversationsCount,
      agentChatDuration,
      csatSatisfactionScore,
    } = rowMetrics;

    const baseRow = {
      id: row.id,
      name: row.name ?? row.title,
      type: props.type,
      conversationsCount: renderCount(conversationsCount),
      avgFirstResponseTime: renderAvgTime(avgFirstResponseTime),
      avgReplyTime: renderAvgTime(avgReplyTime),
      avgResolutionTime: renderAvgTime(avgResolutionTime),
      resolutionsCount: renderCount(resolvedConversationsCount),
      avgFirstResponseTimeRaw: avgFirstResponseTime || 0,
      avgReplyTimeRaw: avgReplyTime || 0,
      avgResolutionTimeRaw: avgResolutionTime || 0,
    };

    if (props.showAgentChatDuration) {
      baseRow.agentChatDuration = renderAvgTime(agentChatDuration);
      baseRow.agentChatDurationRaw = agentChatDuration || 0;
    }

    if (props.showCsatScore) {
      baseRow.csatSatisfactionScore = renderCsatScore(csatSatisfactionScore);
      baseRow.csatSatisfactionScoreRaw = csatSatisfactionScore || 0;
    }

    return baseRow;
  });
});

const fetchReportsWithRetry = async () => {
  const params = {
    since: from.value,
    until: to.value,
    businessHours: businessHours.value,
    userIds: selectedAgents.value.map(agent => agent.id),
    inboxIds: selectedInboxes.value.map(inbox => inbox.id),
    teamIds: selectedTeams.value.map(team => team.id),
    labelIds: selectedLabels.value.map(label => label.id),
    timeSince: timeRange.value.since,
    timeUntil: timeRange.value.until,
  };
  try {
    await store.dispatch(props.actionKey, params);
  } catch {
    try {
      await store.dispatch(props.actionKey, params);
    } catch {
      useAlert(t('REPORT.SUMMARY_FETCHING_FAILED'));
    }
  }
};

const fetchAllData = () => {
  store.dispatch(props.fetchItemsKey);
  fetchReportsWithRetry();
};

onMounted(() => fetchAllData());

const onFilterChange = updatedFilter => {
  from.value = updatedFilter.from;
  to.value = updatedFilter.to;
  businessHours.value = updatedFilter.businessHours;
  if (updatedFilter.timeRange) timeRange.value = updatedFilter.timeRange;
  if (updatedFilter.selectedAgents)
    selectedAgents.value = updatedFilter.selectedAgents;
  if (updatedFilter.selectedInbox)
    selectedInboxes.value = updatedFilter.selectedInbox;
  if (updatedFilter.selectedTeam)
    selectedTeams.value = updatedFilter.selectedTeam;
  if (updatedFilter.selectedLabel)
    selectedLabels.value = updatedFilter.selectedLabel;
  fetchAllData();
};

const onAgentsFilter = agents => {
  selectedAgents.value = agents || [];
  fetchAllData();
};

const onInboxesFilter = inboxes => {
  selectedInboxes.value = inboxes || [];
  fetchAllData();
};

const onTeamsFilter = teams => {
  selectedTeams.value = teams || [];
  fetchAllData();
};

const onLabelsFilter = labels => {
  selectedLabels.value = labels || [];
  fetchAllData();
};

const table = useVueTable({
  get data() {
    return tableData.value;
  },
  get columns() {
    return columns.value;
  },
  enableSorting: true,
  getCoreRowModel: getCoreRowModel(),
  getSortedRowModel: getSortedRowModel(),
});

const downloadReports = async (format = 'csv') => {
  const params = {
    from: from.value,
    to: to.value,
    businessHours: businessHours.value,
    userIds: selectedAgents.value.map(agent => agent.id),
    inboxIds: selectedInboxes.value.map(inbox => inbox.id),
    teamIds: selectedTeams.value.map(team => team.id),
    labelIds: selectedLabels.value.map(label => label.id),
    timeSince: timeRange.value.since,
    timeUntil: timeRange.value.until,
    format,
  };

  let response;

  if (props.type === 'agent') {
    response = await ReportsAPI.getAgentReports(params);
  } else if (props.type === 'label') {
    response = await ReportsAPI.getLabelReports(params);
  } else if (props.type === 'inbox') {
    response = await ReportsAPI.getInboxReports(params);
  } else if (props.type === 'team') {
    response = await ReportsAPI.getTeamReports(params);
  }

  const fileName = `${props.type}_report_${Date.now()}.${format}`;
  const mimeType =
    format === 'xlsx'
      ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      : 'text/csv';

  const blob = new Blob([response.data], { type: mimeType });
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = fileName;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  window.URL.revokeObjectURL(url);
};

defineExpose({ downloadReports });
</script>

<template>
  <div class="flex flex-col gap-3">
    <OverviewReportFilters
      :disabled="isLoading"
      @filter-change="onFilterChange"
    />
    <div class="flex items-center gap-3">
      <ReportsFiltersAgents @agents-filter-selection="onAgentsFilter" />
      <ReportsFiltersInboxes @inbox-filter-selection="onInboxesFilter" />
      <ReportsFiltersTeams @team-filter-selection="onTeamsFilter" />
      <ReportsFiltersLabels @labels-filter-selection="onLabelsFilter" />
    </div>
  </div>
  <div
    class="relative flex-1 overflow-hidden px-2 py-2 mt-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
  >
    <Table
      :table="table"
      :custom-header-class="customHeaderClass"
      :custom-cell-class="customCellClass"
    />
    <Transition
      enter-active-class="transition-opacity duration-300 ease-out"
      leave-active-class="transition-opacity duration-200 ease-in"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
    >
      <div
        v-if="isLoading"
        class="absolute inset-0 flex justify-center pt-[12.5rem] bg-n-solid-1/70 rounded-xl pointer-events-none"
      >
        <Spinner :size="32" class="text-n-brand" />
      </div>
    </Transition>
  </div>
</template>
