<script setup>
import { ref } from 'vue';
import AdvancedReportFilters from 'dashboard/routes/dashboard/settings/reports/components/AdvancedReportFilters.vue';

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
  <AdvancedReportFilters
    section="all_metrics"
    show-time-range-filter
    show-agents-filter
    show-inbox-filter
    show-team-filter
    @filter-change="onFilterChange"
  />
</template>
