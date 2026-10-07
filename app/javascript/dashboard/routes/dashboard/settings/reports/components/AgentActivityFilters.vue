<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import ReportFilterSelector from 'dashboard/routes/dashboard/settings/reports/components/FilterSelector.vue';
import FilterButton from 'dashboard/components/ui/Dropdown/DropdownButton.vue';
import ReportsFiltersAgents from './Filters/Agents.vue';
import ReportsFiltersInboxes from './Filters/Inboxes.vue';
import ReportsFiltersTeams from './Filters/Teams.vue';

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

const extraFilters = computed(() => ({
  hideInactive: hideInactive.value,
  agentIds: selectedAgents.value.map(agent => agent.id),
  inboxIds: selectedInbox.value.map(inbox => inbox.id),
  teamIds: selectedTeam.value.map(team => team.id),
}));

const onApplyExtraFilters = extra => {
  hideInactive.value = Boolean(extra.hideInactive);
  selectedAgents.value = extra.agents || [];
  selectedInbox.value = extra.inboxes || [];
  selectedTeam.value = extra.teams || [];
};

const hasClearableFilters = computed(
  () =>
    selectedAgents.value.length > 0 ||
    selectedInbox.value.length > 0 ||
    selectedTeam.value.length > 0 ||
    hideInactive.value
);

const clearAllFilters = () => {
  selectedAgents.value = [];
  selectedInbox.value = [];
  selectedTeam.value = [];
  hideInactive.value = false;
  emitChange();
};

const onFilterChange = updatedFilter => {
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
      <ReportFilterSelector
        section="agent_activity"
        show-time-range-filter
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

    <!-- Нижняя строка: Фильтры -->
    <div class="flex items-center gap-3">
      <ReportsFiltersAgents
        :selected-agents="selectedAgents"
        @agents-filter-selection="
          selectedAgents = [...$event];
          emitChange();
        "
      />

      <ReportsFiltersInboxes
        :selected-inbox="selectedInbox"
        @inbox-filter-selection="
          selectedInbox = [...$event];
          emitChange();
        "
      />

      <ReportsFiltersTeams
        :selected-team="selectedTeam"
        @team-filter-selection="
          selectedTeam = [...$event];
          emitChange();
        "
      />

      <FilterButton
        v-if="hasClearableFilters"
        :button-text="t('REPORT.FILTER_ACTIONS.CLEAR_ALL')"
        @click="clearAllFilters"
      />
    </div>
  </div>
</template>
