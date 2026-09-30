<script setup>
import { computed, ref, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { formatTime } from '@chatwoot/utils';
import { emitter } from 'shared/helpers/mitt';

import ReportsAPI from 'dashboard/api/reports';
import { useAlert } from 'dashboard/composables';
import BarChart from 'shared/components/charts/BarChart.vue';
import BaseHeatmap from './components/heatmaps/BaseHeatmap.vue';
import ReportHeader from './components/ReportHeader.vue';
import ReportFilterSelector from './components/FilterSelector.vue';

const POLL_INTERVAL = 30_000;

const { t } = useI18n();

const from = ref(0);
const to = ref(0);
const selectedInbox = ref([]);
const selectedTeam = ref([]);
const loading = ref(false);
const pollTimer = ref(null);

const queuedReport = ref({
  summary: {
    queued_customers: 0,
    entered_chat: { value: 0, percentage: 0 },
    left_queue: { value: 0, percentage: 0 },
  },
  waiting_time: {
    time_to_enter_chat: 0,
    time_to_leave_queue: 0,
  },
  daily: [],
  heatmap: [],
});

const toIds = value => value.map(item => item.id || item);
const percent = value => `${Number(value || 0).toFixed(2)}%`;

const summaryCards = computed(() => [
  {
    key: 'queued',
    label: 'QUEUED_CUSTOMERS_REPORTS.CARDS.QUEUED_CUSTOMERS',
    value: queuedReport.value.summary.queued_customers,
    subtitle: null,
  },
  {
    key: 'accepted',
    label: 'QUEUED_CUSTOMERS_REPORTS.CARDS.ENTERED_CHAT',
    value: queuedReport.value.summary.entered_chat.value,
    subtitle: percent(queuedReport.value.summary.entered_chat.percentage),
  },
  {
    key: 'left',
    label: 'QUEUED_CUSTOMERS_REPORTS.CARDS.LEFT_QUEUE',
    value: queuedReport.value.summary.left_queue.value,
    subtitle: percent(queuedReport.value.summary.left_queue.percentage),
  },
]);

const waitingCards = computed(() => [
  {
    key: 'enter',
    label: 'QUEUED_CUSTOMERS_REPORTS.CARDS.TIME_TO_ENTER_CHAT',
    value: formatTime(queuedReport.value.waiting_time.time_to_enter_chat || 0),
  },
  {
    key: 'leave',
    label: 'QUEUED_CUSTOMERS_REPORTS.CARDS.TIME_TO_LEAVE_QUEUE',
    value: formatTime(queuedReport.value.waiting_time.time_to_leave_queue || 0),
  },
]);

const queueFlowCollection = computed(() => {
  const categories = queuedReport.value.daily.map(item => item.date);
  return {
    categories,
    series: [
      {
        id: 'queued_customers',
        label: t('QUEUED_CUSTOMERS_REPORTS.CARDS.QUEUED_CUSTOMERS'),
        color: 'rgb(var(--iris-9))',
        data: queuedReport.value.daily.map(item => item.queued_customers),
      },
      {
        id: 'entered_chat',
        label: t('QUEUED_CUSTOMERS_REPORTS.CARDS.ENTERED_CHAT'),
        color: 'rgb(var(--teal-9))',
        data: queuedReport.value.daily.map(item => item.entered_chat),
      },
      {
        id: 'left_queue',
        label: t('QUEUED_CUSTOMERS_REPORTS.CARDS.LEFT_QUEUE'),
        color: 'rgb(var(--amber-9))',
        data: queuedReport.value.daily.map(item => item.left_queue),
      },
    ],
  };
});

const waitingTimeCollection = computed(() => {
  const categories = queuedReport.value.daily.map(item => item.date);
  return {
    categories,
    series: [
      {
        id: 'time_to_enter_chat',
        label: t('QUEUED_CUSTOMERS_REPORTS.CARDS.TIME_TO_ENTER_CHAT'),
        color: 'rgb(var(--iris-9))',
        data: queuedReport.value.daily.map(item => item.time_to_enter_chat),
      },
      {
        id: 'time_to_leave_queue',
        label: t('QUEUED_CUSTOMERS_REPORTS.CARDS.TIME_TO_LEAVE_QUEUE'),
        color: 'rgb(var(--ruby-9))',
        data: queuedReport.value.daily.map(item => item.time_to_leave_queue),
      },
    ],
  };
});

const formatHeatmapValue = value => {
  if (!value) {
    return t('QUEUED_CUSTOMERS_REPORTS.HEATMAP.NO_CUSTOMERS');
  }

  return value === 1
    ? t('QUEUED_CUSTOMERS_REPORTS.HEATMAP.CUSTOMER', { count: value })
    : t('QUEUED_CUSTOMERS_REPORTS.HEATMAP.CUSTOMERS', { count: value });
};

const fetchQueuedCustomers = async ({ showLoader = false } = {}) => {
  if (!from.value) return;
  if (showLoader) loading.value = true;
  try {
    const response = await ReportsAPI.getQueuedCustomers({
      from: from.value,
      to: to.value,
      inboxIds: toIds(selectedInbox.value),
      teamIds: toIds(selectedTeam.value),
    });
    queuedReport.value = response.data;
  } catch (error) {
    useAlert(t('QUEUED_CUSTOMERS_REPORTS.FETCH_FAILED'));
  } finally {
    if (showLoader) loading.value = false;
  }
};

const stopPolling = () => {
  if (pollTimer.value) {
    clearInterval(pollTimer.value);
    pollTimer.value = null;
  }
};

const startPolling = () => {
  stopPolling();
  pollTimer.value = setInterval(() => {
    fetchQueuedCustomers({ showLoader: false });
  }, POLL_INTERVAL);
};

const refreshQueuedCustomers = () => {
  fetchQueuedCustomers({ showLoader: false });
};

const onFilterChange = updatedFilter => {
  from.value = updatedFilter.from;
  to.value = updatedFilter.to;
  selectedInbox.value = updatedFilter.selectedInbox || [];
  selectedTeam.value = updatedFilter.selectedTeam || [];
  fetchQueuedCustomers({ showLoader: true });
  startPolling();
};

onMounted(() => {
  emitter.on('fetch_conversation_stats', refreshQueuedCustomers);
  startPolling();
});

onUnmounted(() => {
  emitter.off('fetch_conversation_stats', refreshQueuedCustomers);
  stopPolling();
});
</script>

<template>
  <ReportHeader
    :header-title="$t('QUEUED_CUSTOMERS_REPORTS.HEADER')"
    :header-description="$t('QUEUED_CUSTOMERS_REPORTS.DESCRIPTION')"
  />

  <div class="flex flex-col gap-4 pb-6">
    <ReportFilterSelector
      :show-agents-filter="false"
      :show-group-by-filter="false"
      :show-business-hours-switch="false"
      show-time-range-filter
      show-team-filter
      show-inbox-filter
      @filter-change="onFilterChange"
    />

    <section
      class="px-6 py-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
    >
      <div class="grid gap-3 md:grid-cols-3">
        <div
          v-for="card in summaryCards"
          :key="card.key"
          class="rounded-lg border border-n-container p-4"
        >
          <p class="text-sm text-n-slate-11">{{ $t(card.label) }}</p>
          <p class="mt-2 text-2xl font-semibold text-n-slate-12">
            {{ card.value }}
          </p>
          <p v-if="card.subtitle" class="mt-1 text-xs text-n-slate-11">
            {{ card.subtitle }}
          </p>
        </div>
      </div>
      <div class="relative mt-4 h-72">
        <div
          v-if="loading"
          class="absolute inset-0 z-10 flex items-center justify-center rounded-lg bg-n-solid-2/70 backdrop-blur-[2px]"
        >
          <div
            class="h-5 w-5 animate-spin rounded-full border-2 border-n-slate-11 border-t-transparent"
          />
        </div>
        <BarChart
          v-if="queuedReport.daily.length"
          :data="queueFlowCollection"
          :aria-label="$t('QUEUED_CUSTOMERS_REPORTS.QUEUE_FLOW_ARIA_LABEL')"
        />
      </div>
    </section>

    <section
      class="px-6 py-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
    >
      <div class="grid gap-3 md:grid-cols-2">
        <div
          v-for="card in waitingCards"
          :key="card.key"
          class="rounded-lg border border-n-container p-4"
        >
          <p class="text-sm text-n-slate-11">{{ $t(card.label) }}</p>
          <p class="mt-2 text-2xl font-semibold text-n-slate-12">
            {{ card.value }}
          </p>
        </div>
      </div>
      <div class="relative mt-4 h-72">
        <div
          v-if="loading"
          class="absolute inset-0 z-10 flex items-center justify-center rounded-lg bg-n-solid-2/70 backdrop-blur-[2px]"
        >
          <div
            class="h-5 w-5 animate-spin rounded-full border-2 border-n-slate-11 border-t-transparent"
          />
        </div>
        <BarChart
          v-if="queuedReport.daily.length"
          :data="waitingTimeCollection"
          :aria-label="$t('QUEUED_CUSTOMERS_REPORTS.WAITING_TIME_ARIA_LABEL')"
        />
      </div>
    </section>

    <section
      class="px-6 py-5 shadow outline-1 outline outline-n-container rounded-xl bg-n-solid-2"
    >
      <h3 class="text-base font-medium text-n-slate-12">
        {{ $t('QUEUED_CUSTOMERS_REPORTS.HEATMAP_TITLE') }}
      </h3>
      <div class="mt-4">
        <BaseHeatmap
          :heatmap-data="queuedReport.heatmap"
          :number-of-rows="7"
          :is-loading="loading"
          color-scheme="green"
          :aria-label="$t('QUEUED_CUSTOMERS_REPORTS.HEATMAP_ARIA_LABEL')"
          :format-value="formatHeatmapValue"
        />
      </div>
    </section>
  </div>
</template>
