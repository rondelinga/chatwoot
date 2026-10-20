<script setup>
import { computed, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import {
  activeChatForAgent,
  chatCounts,
} from 'dashboard/routes/dashboard/supervision/helpers';
import { useSupervisionLive } from 'dashboard/routes/dashboard/supervision/useSupervisionLive';
import ConversationView from 'dashboard/routes/dashboard/conversation/ConversationView.vue';
import AgentList from './components/AgentList.vue';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();

useSupervisionLive();

onMounted(() => {
  store.dispatch('agents/get');
});

const agents = useMapGetter('agents/getAgents');
const openConversations = useMapGetter('supervision/getOpenConversations');
const typingByUserId = useMapGetter('supervision/getTypingByUserId');

const counts = computed(() => chatCounts(openConversations.value).agents);
const typingIds = computed(
  () => new Set(Object.keys(typingByUserId.value).map(id => Number(id)))
);
const agentId = computed(() => route.params.agentId || '');
const conversationId = computed(() => route.params.conversationId || 0);

const selectAgent = async id => {
  if (String(id) === String(agentId.value) && conversationId.value) return;

  let conversations = openConversations.value;
  if (!conversations.length) {
    await store.dispatch('supervision/refreshOpenConversations');
    conversations = store.getters['supervision/getOpenConversations'];
  }

  const chat = activeChatForAgent(conversations, id);
  router.push({
    name: chat ? 'supervision_supervise_conversation' : 'supervision_supervise',
    params: {
      accountId: route.params.accountId,
      agentId: id,
      ...(chat ? { conversationId: chat.id } : {}),
    },
  });
};
</script>

<template>
  <div class="flex h-full min-h-0 w-full">
    <AgentList
      :agents="agents"
      :chat-counts="counts"
      :typing-ids="typingIds"
      :selected-agent-id="Number(agentId) || null"
      @select="selectAgent"
    />
    <div v-if="agentId" class="flex h-full min-w-0 flex-1">
      <ConversationView
        :key="agentId"
        :agent-id="agentId"
        :conversation-id="conversationId"
      />
    </div>
    <div
      v-else
      class="flex flex-1 items-center justify-center text-sm text-n-slate-11"
    >
      {{ t('SUPERVISION.SELECT_AGENT') }}
    </div>
  </div>
</template>
