<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import AdvancedReportFilters from 'dashboard/routes/dashboard/settings/reports/components/AdvancedReportFilters.vue';

const props = defineProps({
  initialSince: {
    type: Number,
    default: null,
  },
  initialUntil: {
    type: Number,
    default: null,
  },
  initialHideInactive: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['filtersChange']);

const { t } = useI18n();
const hideInactive = ref(false);
const selectedAgents = ref([]);
const selectedInbox = ref([]);
const selectedTeam = ref([]);

const filterData = ref({
  from: 0,
  to: 0,
  businessHours: false,
  timeRange: {
    since: '00:00',
    until: '23:59',
  },
});

watch(
  () => props.initialSince,
  v => {
    if (v) {
      filterData.value.from = Math.floor(v / 1000);
    }
  },
  { immediate: true }
);

watch(
  () => props.initialUntil,
  v => {
    if (v) {
      filterData.value.to = Math.floor(v / 1000);
    }
  },
  { immediate: true }
);

watch(
  () => props.initialHideInactive,
  v => {
    hideInactive.value = v;
  },
  { immediate: true }
);

const applyTime = (timestamp, time) => {
  if (!timestamp) return null;

  const d = new Date(timestamp);
  const [h, m] = time.split(':').map(Number);
  d.setUTCHours(h, m, 0, 0);
  return d.getTime();
};

const emitChange = () => {
  const sinceWithTime = applyTime(
    filterData.value.from * 1000,
    filterData.value.timeRange.since
  );
  const untilWithTime = applyTime(
    filterData.value.to * 1000,
    filterData.value.timeRange.until
  );

  emit('filtersChange', {
    since: sinceWithTime,
    until: untilWithTime,
    hideInactive: hideInactive.value,
    userIds: selectedAgents.value.map(agent => agent.id),
    teamIds: selectedTeam.value.map(team => team.id),
    inboxIds: selectedInbox.value.map(inbox => inbox.id),
    businessHours: filterData.value.businessHours,
    timeRange: filterData.value.timeRange,
  });
};

const extraFilters = computed(() => ({ hideInactive: hideInactive.value }));

const onApplyExtraFilters = extra => {
  hideInactive.value = Boolean(extra.hideInactive);
};

const onFilterChange = updatedFilter => {
  selectedAgents.value = updatedFilter.selectedAgents;
  selectedInbox.value = updatedFilter.selectedInbox;
  selectedTeam.value = updatedFilter.selectedTeam;
  filterData.value = {
    from: updatedFilter.from,
    to: updatedFilter.to,
    businessHours: updatedFilter.businessHours,
    timeRange: updatedFilter.timeRange,
  };
  emitChange();
};
</script>

<template>
  <div
    class="p-4 rounded-xl bg-n-solid-2 outline outline-1 outline-n-container"
  >
    <div class="gap-4 mb-3">
      <AdvancedReportFilters
        section="agent_activity"
        show-time-range-filter
        show-agents-filter
        show-inbox-filter
        show-team-filter
        :extra-filters="extraFilters"
        @filter-change="onFilterChange"
        @apply-extra-filters="onApplyExtraFilters"
      />
      <label
        class="flex items-center gap-2 text-sm whitespace-nowrap ml-auto cursor-pointer"
      >
        <input
          v-model="hideInactive"
          type="checkbox"
          class="rounded"
          @change="emitChange"
        />
        {{ t('AGENT_ACTIVITY_REPORTS.HIDE_INACTIVE') }}
      </label>
    </div>
  </div>
</template>
