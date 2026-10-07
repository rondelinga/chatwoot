<script setup>
import { computed, ref } from 'vue';
import ReportFilterSelector from 'dashboard/routes/dashboard/settings/reports/components/FilterSelector.vue';
import FilterButton from 'dashboard/components/ui/Dropdown/DropdownButton.vue';
import ReportsFiltersAgents from './Filters/Agents.vue';
import ReportsFiltersInboxes from './Filters/Inboxes.vue';
import ReportsFiltersTeams from './Filters/Teams.vue';

const emit = defineEmits(['filtersChange']);

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

const emitChange = () => {
  emit('filtersChange', {
    since: filterData.value.from,
    until: filterData.value.to,
    userIds: selectedAgents.value.map(agent => agent.id),
    teamIds: selectedTeam.value.map(team => team.id),
    inboxIds: selectedInbox.value.map(inbox => inbox.id),
    businessHours: filterData.value.businessHours,
    timeRange: filterData.value.timeRange,
  });
};

const extraFilters = computed(() => ({
  agentIds: selectedAgents.value.map(agent => agent.id),
  inboxIds: selectedInbox.value.map(inbox => inbox.id),
  teamIds: selectedTeam.value.map(team => team.id),
}));

const onApplyExtraFilters = extra => {
  selectedAgents.value = extra.agents || [];
  selectedInbox.value = extra.inboxes || [];
  selectedTeam.value = extra.teams || [];
};

const hasClearableFilters = computed(
  () =>
    selectedAgents.value.length > 0 ||
    selectedInbox.value.length > 0 ||
    selectedTeam.value.length > 0
);

const clearAllFilters = () => {
  selectedAgents.value = [];
  selectedInbox.value = [];
  selectedTeam.value = [];
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
  <div class="flex flex-col gap-3">
    <ReportFilterSelector
      section="all_metrics"
      show-time-range-filter
      :extra-filters="extraFilters"
      @filter-change="onFilterChange"
      @apply-extra-filters="onApplyExtraFilters"
    />

    <div
      class="rounded-xl outline outline-1 outline-n-container flex items-center gap-3 flex-wrap"
    >
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
        :button-text="$t('REPORT.FILTER_ACTIONS.CLEAR_ALL')"
        @click="clearAllFilters"
      />
    </div>
  </div>
</template>
