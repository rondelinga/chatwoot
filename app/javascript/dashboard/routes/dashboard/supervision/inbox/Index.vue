<script setup>
import { computed, onMounted, ref } from 'vue';
import { useStore } from 'vuex';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import Avatar from 'next/avatar/Avatar.vue';
import ChannelIcon from 'next/icon/ChannelIcon.vue';
import {
  activeChatForAgent,
  assigneeOf,
  chatCounts,
  compareInboxAgents,
} from 'dashboard/routes/dashboard/supervision/helpers';
import { useSupervisionLive } from 'dashboard/routes/dashboard/supervision/useSupervisionLive';

const { t } = useI18n();
const store = useStore();
const router = useRouter();
const { accountScopedRoute } = useAccount();

useSupervisionLive();

onMounted(() => {
  store.dispatch('agents/get');
  store.dispatch('agentBots/get');
  store.dispatch('inboxes/get');
});

const activeTab = ref('agents');
const agents = useMapGetter('agents/getAgents');
const inboxes = useMapGetter('inboxes/getInboxes');
const bots = useMapGetter('agentBots/getBots');
const openConversations = useMapGetter('supervision/getOpenConversations');

const counts = computed(() => chatCounts(openConversations.value));

const agentRows = computed(() =>
  [...agents.value].sort((left, right) =>
    compareInboxAgents(left, right, counts.value.agents)
  )
);

const inboxRows = computed(() =>
  [...inboxes.value].sort((left, right) => {
    const leftCount = counts.value.inboxes[left.id] || 0;
    const rightCount = counts.value.inboxes[right.id] || 0;
    if (leftCount !== rightCount) return rightCount - leftCount;
    return (left.name || '').localeCompare(right.name || '');
  })
);

const botRows = computed(() => {
  const known = new Map(
    bots.value.map(bot => [
      `AgentBot:${bot.id}`,
      { ...bot, id: `AgentBot:${bot.id}` },
    ])
  );
  openConversations.value.forEach(conversation => {
    const assignee = assigneeOf(conversation);
    if (assignee?.kind !== 'bot' || known.has(assignee.id)) return;
    known.set(assignee.id, {
      id: assignee.id,
      name: assignee.name,
      thumbnail: assignee.thumbnail,
    });
  });

  return [...known.values()].sort((left, right) => {
    const leftCount = counts.value.bots[left.id] || 0;
    const rightCount = counts.value.bots[right.id] || 0;
    if (leftCount !== rightCount) return rightCount - leftCount;
    return (left.name || '').localeCompare(right.name || '');
  });
});

const STATUS_BADGE = {
  online: {
    badge: 'bg-n-teal-3 text-n-teal-11',
    dot: 'bg-n-teal-10',
  },
  busy: {
    badge: 'bg-n-amber-3 text-n-amber-11',
    dot: 'bg-n-amber-10',
  },
  offline: {
    badge: 'bg-n-slate-3 text-n-slate-11',
    dot: 'bg-n-slate-10',
  },
};

const statusTone = agent =>
  STATUS_BADGE[agent.availability_status] || STATUS_BADGE.offline;

const statusLabel = agent => {
  const status = agent.availability_status || 'offline';
  if (status === 'online') return t('SUPERVISION.ONLINE');
  if (status === 'busy') return t('SUPERVISION.BUSY');
  return t('SUPERVISION.OFFLINE');
};

const openSupervise = async agentId => {
  let conversations = openConversations.value;
  if (!conversations.length) {
    await store.dispatch('supervision/refreshOpenConversations');
    conversations = store.getters['supervision/getOpenConversations'];
  }

  const chat = activeChatForAgent(conversations, agentId);
  if (!chat) {
    router.push(accountScopedRoute('supervision_supervise', { agentId }));
    return;
  }

  router.push(
    accountScopedRoute('supervision_supervise_conversation', {
      agentId,
      conversationId: chat.id,
    })
  );
};

const tabs = computed(() => [
  { key: 'agents', label: t('SUPERVISION.INBOX_AGENTS') },
  { key: 'sources', label: t('SUPERVISION.INBOX_SOURCES') },
  { key: 'bots', label: t('SUPERVISION.INBOX_BOTS') },
]);
</script>

<template>
  <section class="flex h-full min-h-0 w-full flex-col bg-n-background">
    <div class="flex gap-1 border-b border-n-weak px-4">
      <button
        v-for="tab in tabs"
        :key="tab.key"
        type="button"
        class="border-b-2 px-3 py-3 text-sm"
        :class="
          activeTab === tab.key
            ? 'border-n-brand text-n-slate-12'
            : 'border-transparent text-n-slate-11'
        "
        @click="activeTab = tab.key"
      >
        {{ tab.label }}
      </button>
    </div>

    <div class="min-h-0 flex-1 overflow-auto p-4">
      <table
        v-if="activeTab === 'agents'"
        class="w-full text-sm [&_th]:text-start"
      >
        <thead>
          <tr class="text-start text-n-slate-11">
            <th class="px-3 py-2 font-medium">
              {{ t('SUPERVISION.COLUMN_AGENT') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ t('SUPERVISION.COLUMN_STATUS') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ t('SUPERVISION.COLUMN_OPEN_CHATS') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ t('SUPERVISION.COLUMN_ACTION') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="agent in agentRows"
            :key="agent.id"
            class="border-t border-n-weak"
          >
            <td class="px-3 py-2">
              <span class="flex items-center gap-2">
                <Avatar
                  :name="agent.name"
                  :src="agent.thumbnail"
                  :size="28"
                  :status="agent.availability_status || 'offline'"
                  rounded-full
                />
                <span class="text-n-slate-12">{{ agent.name }}</span>
              </span>
            </td>
            <td class="px-3 py-2">
              <span
                class="inline-flex items-center gap-1.5 rounded-full px-2 py-0.5 text-xs font-medium"
                :class="statusTone(agent).badge"
              >
                <span
                  class="size-1.5 rounded-full"
                  :class="statusTone(agent).dot"
                />
                {{ statusLabel(agent) }}
              </span>
            </td>
            <td class="px-3 py-2 text-n-slate-12">
              {{ counts.agents[agent.id] || 0 }}
            </td>
            <td class="px-3 py-2">
              <button
                type="button"
                class="text-n-brand"
                @click="openSupervise(agent.id)"
              >
                {{ t('SUPERVISION.OPEN_SUPERVISE') }}
              </button>
            </td>
          </tr>
        </tbody>
      </table>

      <table
        v-else-if="activeTab === 'sources'"
        class="w-full text-sm [&_th]:text-start"
      >
        <thead>
          <tr class="text-start text-n-slate-11">
            <th class="px-3 py-2 font-medium">
              {{ t('SUPERVISION.COLUMN_SOURCE') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ t('SUPERVISION.COLUMN_OPEN_CHATS') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="inbox in inboxRows"
            :key="inbox.id"
            class="border-t border-n-weak"
          >
            <td class="px-3 py-2">
              <span class="flex items-center gap-2 text-n-slate-12">
                <ChannelIcon :inbox="inbox" class="size-4" />
                {{ inbox.name }}
              </span>
            </td>
            <td class="px-3 py-2 text-n-slate-12">
              {{ counts.inboxes[inbox.id] || 0 }}
            </td>
          </tr>
        </tbody>
      </table>

      <table v-else class="w-full text-sm [&_th]:text-start">
        <thead>
          <tr class="text-start text-n-slate-11">
            <th class="px-3 py-2 font-medium">
              {{ t('SUPERVISION.COLUMN_BOT') }}
            </th>
            <th class="px-3 py-2 font-medium">
              {{ t('SUPERVISION.COLUMN_OPEN_CHATS') }}
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="bot in botRows"
            :key="bot.id"
            class="border-t border-n-weak"
          >
            <td class="px-3 py-2">
              <span class="flex items-center gap-2 text-n-slate-12">
                <Avatar
                  :name="bot.name"
                  :src="bot.thumbnail"
                  :size="28"
                  icon-name="i-lucide-bot"
                  rounded-full
                />
                {{ bot.name }}
              </span>
            </td>
            <td class="px-3 py-2 text-n-slate-12">
              {{ counts.bots[bot.id] || 0 }}
            </td>
          </tr>
          <tr v-if="!botRows.length">
            <td colspan="2" class="px-3 py-6 text-n-slate-11">
              {{ t('SUPERVISION.EMPTY_TABLE') }}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
  </section>
</template>
