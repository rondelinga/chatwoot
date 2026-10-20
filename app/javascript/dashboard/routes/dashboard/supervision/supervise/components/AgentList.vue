<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { compareSuperviseAgents } from 'dashboard/routes/dashboard/supervision/helpers';
import AgentListItem from './AgentListItem.vue';

const props = defineProps({
  agents: { type: Array, default: () => [] },
  chatCounts: { type: Object, default: () => ({}) },
  typingIds: { type: Set, default: () => new Set() },
  selectedAgentId: { type: Number, default: null },
});

const emit = defineEmits(['select']);
const { t } = useI18n();

const query = ref('');
const pinnedIds = ref([]);

const pinnedAgents = computed(() =>
  props.agents.filter(agent => pinnedIds.value.includes(agent.id))
);

const suggestions = computed(() => {
  const term = query.value.trim().toLowerCase();
  if (!term) return [];
  return props.agents.filter(agent =>
    (agent.name || '').toLowerCase().includes(term)
  );
});

const visibleAgents = computed(() => {
  const term = query.value.trim().toLowerCase();
  let list = props.agents;
  if (pinnedIds.value.length) {
    list = list.filter(agent => pinnedIds.value.includes(agent.id));
  } else if (term) {
    list = list.filter(agent =>
      (agent.name || '').toLowerCase().includes(term)
    );
  }

  return [...list].sort((left, right) =>
    compareSuperviseAgents(left, right, props.chatCounts, props.typingIds)
  );
});

const groups = computed(() => [
  {
    key: 'online',
    label: t('SUPERVISION.ONLINE'),
    agents: visibleAgents.value.filter(
      agent => (agent.availability_status || 'offline') === 'online'
    ),
  },
  {
    key: 'busy',
    label: t('SUPERVISION.BUSY'),
    agents: visibleAgents.value.filter(
      agent => agent.availability_status === 'busy'
    ),
  },
  {
    key: 'offline',
    label: t('SUPERVISION.OFFLINE'),
    agents: visibleAgents.value.filter(
      agent => (agent.availability_status || 'offline') === 'offline'
    ),
  },
]);

const pinAgent = agent => {
  if (!pinnedIds.value.includes(agent.id)) {
    pinnedIds.value = [...pinnedIds.value, agent.id];
  }
  query.value = '';
  emit('select', agent.id);
};

const onSelect = agentId => {
  const agent = props.agents.find(item => item.id === agentId);
  if (query.value.trim() && agent) {
    pinAgent(agent);
    return;
  }
  emit('select', agentId);
};

const unpinAgent = agentId => {
  pinnedIds.value = pinnedIds.value.filter(id => id !== agentId);
};
</script>

<template>
  <aside
    class="flex h-full w-[13.75rem] shrink-0 flex-col border-e border-n-weak bg-n-background"
  >
    <div class="border-b border-n-weak p-2">
      <input
        v-model="query"
        type="search"
        class="w-full rounded-lg border border-n-weak bg-n-background px-2 py-1.5 text-sm text-n-slate-12 outline-none placeholder:text-n-slate-10"
        :placeholder="t('SUPERVISION.SEARCH_AGENTS')"
      />
      <ul
        v-if="suggestions.length"
        class="mt-1 max-h-40 overflow-y-auto rounded-lg border border-n-weak bg-n-background"
      >
        <li v-for="agent in suggestions" :key="agent.id">
          <button
            type="button"
            class="w-full px-2 py-1.5 text-start text-sm text-n-slate-12 hover:bg-n-alpha-2"
            @click="pinAgent(agent)"
          >
            {{ agent.name }}
          </button>
        </li>
      </ul>
      <div v-if="pinnedAgents.length" class="mt-2 flex flex-wrap gap-1">
        <button
          v-for="agent in pinnedAgents"
          :key="agent.id"
          type="button"
          class="inline-flex items-center gap-1 rounded-full bg-n-brand/10 px-2 py-0.5 text-xs text-n-slate-12"
          @click="unpinAgent(agent.id)"
        >
          {{ agent.name }}
          <span class="i-lucide-x size-3" aria-hidden="true" />
        </button>
      </div>
    </div>
    <div class="flex-1 overflow-y-auto p-2">
      <p v-if="!visibleAgents.length" class="px-2 py-4 text-sm text-n-slate-11">
        {{ t('SUPERVISION.NO_AGENTS') }}
      </p>
      <section v-for="group in groups" :key="group.key" class="mb-3">
        <template v-if="group.agents.length">
          <h3 class="px-2 py-1 text-xs font-medium text-n-slate-11">
            {{ group.label }}
          </h3>
          <AgentListItem
            v-for="agent in group.agents"
            :key="agent.id"
            :agent="agent"
            :chat-count="chatCounts[agent.id] || 0"
            :is-typing="typingIds.has(agent.id)"
            :is-selected="agent.id === selectedAgentId"
            @select="onSelect"
          />
        </template>
      </section>
    </div>
  </aside>
</template>
