<script setup>
import { watch } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useLiveRefresh } from 'dashboard/composables/useLiveRefresh';

import AgentTable from 'dashboard/routes/dashboard/settings/reports/components/overview/AgentTable.vue';

const show = defineModel('show', { type: Boolean, default: false });

const store = useStore();
const uiFlags = useMapGetter('getOverviewUIFlags');
const agentConversationMetric = useMapGetter('getAgentConversationMetric');
const agents = useMapGetter('agents/getAgents');

const fetchData = () => store.dispatch('fetchAgentConversationMetric');

const { startRefetching, stopRefetching } = useLiveRefresh(fetchData);

watch(show, isOpen => {
  if (isOpen) {
    store.dispatch('agents/get');
    fetchData();
    startRefetching();
    return;
  }
  stopRefetching();
});
</script>

<template>
  <woot-modal v-model:show="show" size="modal-big">
    <woot-modal-header
      :header-title="$t('OVERVIEW_REPORTS.AGENT_CONVERSATIONS.HEADER')"
    />
    <div class="px-6 pb-6">
      <AgentTable
        :agents="agents"
        :agent-metrics="agentConversationMetric"
        :is-loading="uiFlags.isFetchingAgentConversationMetric"
      />
    </div>
  </woot-modal>
</template>
