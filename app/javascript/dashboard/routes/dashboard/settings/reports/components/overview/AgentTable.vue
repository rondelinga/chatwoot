<script setup>
import { computed, h, ref, watch } from 'vue';
import {
  useVueTable,
  createColumnHelper,
  getCoreRowModel,
  getPaginationRowModel,
} from '@tanstack/vue-table';
import { useI18n } from 'vue-i18n';
import { useUISettings } from 'dashboard/composables/useUISettings';

import Spinner from 'shared/components/Spinner.vue';
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import Table from 'dashboard/components/table/Table.vue';
import Pagination from 'dashboard/components/table/Pagination.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import AgentCell from './AgentCell.vue';
import { compareOverviewAgents } from './overviewAgentSort';

const { agents, agentMetrics } = defineProps({
  agents: {
    type: Array,
    default: () => [],
  },
  agentMetrics: {
    type: Array,
    default: () => [],
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

// UI Settings key for agent table page size
const AGENT_TABLE_PAGE_SIZE_KEY = 'report_overview_agent_table_page_size';

// Get the saved page size from UI settings or default to 10
const getPageSize = () => {
  return uiSettings.value[AGENT_TABLE_PAGE_SIZE_KEY] || 10;
};

const handlePageSizeChange = pageSize => {
  updateUISettings({ [AGENT_TABLE_PAGE_SIZE_KEY]: pageSize });
};

const searchQuery = ref('');

const getAgentMetrics = id =>
  agentMetrics.find(metrics => metrics.assignee_id === Number(id)) || {};

const filteredAgents = computed(() => {
  const query = searchQuery.value.trim().toLowerCase();
  if (!query) return agents;

  return agents.filter(agent => {
    const name = (agent.available_name || agent.name || '').toLowerCase();
    const email = (agent.email || '').toLowerCase();
    return name.includes(query) || email.includes(query);
  });
});

const tableData = computed(() =>
  filteredAgents.value
    .map(agent => {
      const metric = getAgentMetrics(agent.id);
      return {
        agent: agent.available_name || agent.name,
        email: agent.email,
        thumbnail: agent.thumbnail,
        open: metric.open || 0,
        unattended: metric.unattended || 0,
        status: agent.availability_status,
      };
    })
    .sort(compareOverviewAgents)
);

const hasSearchQuery = computed(() => searchQuery.value.trim().length > 0);

const defaulSpanRender = cellProps =>
  h(
    'span',

    {
      class: cellProps.getValue()
        ? 'capitalize text-n-slate-12'
        : 'capitalize text-n-slate-11',
    },
    cellProps.getValue() ? cellProps.getValue() : '---'
  );

const columnHelper = createColumnHelper();
const columns = [
  columnHelper.accessor('agent', {
    header: t('OVERVIEW_REPORTS.AGENT_CONVERSATIONS.TABLE_HEADER.AGENT'),
    cell: cellProps => h(AgentCell, cellProps),

    size: 250,
  }),
  columnHelper.accessor('open', {
    header: t('OVERVIEW_REPORTS.AGENT_CONVERSATIONS.TABLE_HEADER.OPEN'),
    cell: defaulSpanRender,
    size: 100,
  }),
  columnHelper.accessor('unattended', {
    header: t('OVERVIEW_REPORTS.AGENT_CONVERSATIONS.TABLE_HEADER.UNATTENDED'),
    cell: defaulSpanRender,
    size: 100,
  }),
];

const table = useVueTable({
  get data() {
    return tableData.value;
  },
  columns,
  enableSorting: false,
  autoResetPageIndex: false,
  getCoreRowModel: getCoreRowModel(),
  getPaginationRowModel: getPaginationRowModel(),
  initialState: {
    pagination: {
      pageSize: getPageSize(),
    },
  },
});

const clampPageIndex = rows => {
  const { pageIndex, pageSize } = table.getState().pagination;
  const lastPageIndex = Math.max(0, Math.ceil(rows.length / pageSize) - 1);
  if (pageIndex > lastPageIndex) table.setPageIndex(lastPageIndex);
};

watch(searchQuery, () => {
  table.setPageIndex(0);
});

watch(tableData, clampPageIndex);
</script>

<template>
  <div class="flex flex-col flex-1 min-h-0 gap-3">
    <Input
      v-if="agents.length"
      v-model="searchQuery"
      size="sm"
      :placeholder="
        $t('OVERVIEW_REPORTS.AGENT_CONVERSATIONS.SEARCH_PLACEHOLDER')
      "
    />
    <div
      v-if="!isLoading && agents.length"
      class="min-h-0 max-h-[80vh] overflow-y-auto flex-1"
    >
      <Table :table="table" />
    </div>
    <Pagination
      v-if="!isLoading && tableData.length"
      :table="table"
      show-page-size-selector
      :default-page-size="getPageSize()"
      @page-size-change="handlePageSizeChange"
    />
    <div
      v-if="isLoading"
      class="items-center flex text-base justify-center p-8"
    >
      <Spinner />
      <span>
        {{ $t('OVERVIEW_REPORTS.AGENT_CONVERSATIONS.LOADING_MESSAGE') }}
      </span>
    </div>
    <EmptyState
      v-else-if="!isLoading && !agents.length"
      :title="$t('OVERVIEW_REPORTS.AGENT_CONVERSATIONS.NO_AGENTS')"
    />
    <EmptyState
      v-else-if="!isLoading && hasSearchQuery && !tableData.length"
      :title="$t('OVERVIEW_REPORTS.AGENT_CONVERSATIONS.NO_SEARCH_RESULTS')"
    />
  </div>
</template>
