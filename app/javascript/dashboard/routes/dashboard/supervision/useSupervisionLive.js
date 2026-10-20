import { onMounted, onUnmounted, watch } from 'vue';
import { useStore } from 'vuex';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { createSupervisorTypingChannel } from 'dashboard/helper/supervisorTyping';

const REFRESH_MS = 30000;

export function useSupervisionLive() {
  const store = useStore();
  let timer = null;
  let typingChannel = null;

  const onEvent = payload => {
    store.dispatch('supervision/applyRealtime', payload);
  };

  const onTypingReceived = payload => {
    if (payload?.event !== 'supervisor_typing_update') return;
    onEvent({
      event: 'conversation.supervisor_typing',
      data: payload.data,
    });
  };

  const connectTyping = conversationId => {
    const user = store.getters.getCurrentUser;
    const accountId = store.getters.getCurrentAccountId;
    if (!user?.pubsub_token || !accountId) return;

    if (!typingChannel) {
      typingChannel = createSupervisorTypingChannel({
        accountId,
        userId: user.id,
        pubsubToken: user.pubsub_token,
        onReceived: onTypingReceived,
      });
    }
    typingChannel.subscribe(conversationId);
  };

  onMounted(() => {
    emitter.on(BUS_EVENTS.SUPERVISION_EVENT, onEvent);
    store.dispatch('supervision/refreshOpenConversations');
    timer = setInterval(() => {
      store.dispatch('supervision/refreshOpenConversations');
    }, REFRESH_MS);
  });

  watch(
    () =>
      store.getters.getSelectedChat?.id ||
      store.getters['supervision/getOpenConversations'][0]?.id ||
      null,
    conversationId => {
      if (!conversationId) return;
      connectTyping(conversationId);
    }
  );

  onUnmounted(() => {
    emitter.off(BUS_EVENTS.SUPERVISION_EVENT, onEvent);
    clearInterval(timer);
    typingChannel?.disconnect();
    typingChannel = null;
  });
}
