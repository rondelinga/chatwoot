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
import OverviewReportFilters from './components/OverviewReportFilters.vue';

const { t } = useI18n();

const from = ref(0);
const to = ref(0);
const selectedInbox = ref([]);
const selectedTeam = ref([]);
const loading = ref(false);
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
  const labels = queuedReport.value.daily.map(item => item.date);
  return {
    labels,
    datasets: [
      {
        label: t('QUEUED_CUSTOMERS_REPORTS.CARDS.QUEUED_CUSTOMERS'),
        data: queuedReport.value.daily.map(item => item.queued_customers),
        backgroundColor: '#3B82F6',
      },
      {
        label: t('QUEUED_CUSTOMERS_REPORTS.CARDS.ENTERED_CHAT'),
        data: queuedReport.value.daily.map(item => item.entered_chat),
        backgroundColor: '#10B981',
      },
      {
        label: t('QUEUED_CUSTOMERS_REPORTS.CARDS.LEFT_QUEUE'),
        data: queuedReport.value.daily.map(item => item.left_queue),
        backgroundColor: '#F97316',
      },
    ],
  };
});

const waitingTimeCollection = computed(() => {
  const labels = queuedReport.value.daily.map(item => item.date);
  return {
    labels,
    datasets: [
      {
        label: t('QUEUED_CUSTOMERS_REPORTS.CARDS.TIME_TO_ENTER_CHAT'),
        data: queuedReport.value.daily.map(item => item.time_to_enter_chat),
        backgroundColor: '#6366F1',
      },
      {
        label: t('QUEUED_CUSTOMERS_REPORTS.CARDS.TIME_TO_LEAVE_QUEUE'),
        data: queuedReport.value.daily.map(item => item.time_to_leave_queue),
        backgroundColor: '#EC4899',
      },
    ],
  };
});

const fetchQueuedCustomers = async () => {
  if (!from.value) return;
  loading.value = true;
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
    loading.value = false;
  }
};

const onFilterChange = updatedFilter => {
  from.value = updatedFilter.from;
  to.value = updatedFilter.to;
  selectedInbox.value = updatedFilter.selectedInbox || [];
  selectedTeam.value = updatedFilter.selectedTeam || [];
  fetchQueuedCustomers();
};

onMounted(() => {
  emitter.on('fetch_conversation_stats', fetchQueuedCustomers);
});

onUnmounted(() => {
  emitter.off('fetch_conversation_stats', fetchQueuedCustomers);
});
</script>

<template>
  <ReportHeader
    :header-title="$t('QUEUED_CUSTOMERS_REPORTS.HEADER')"
    :header-description="$t('QUEUED_CUSTOMERS_REPORTS.DESCRIPTION')"
  />

  <div class="flex flex-col gap-4 pb-6">
    <OverviewReportFilters
      :disabled="loading"
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
      <div class="mt-4 h-72">
        <BarChart
          v-if="!loading && queuedReport.daily.length"
          :collection="queueFlowCollection"
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
      <div class="mt-4 h-72">
        <BarChart
          v-if="!loading && queuedReport.daily.length"
          :collection="waitingTimeCollection"
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
        />
      </div>
    </section>
  </div>
</template>
