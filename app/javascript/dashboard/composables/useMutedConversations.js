import { computed, ref } from 'vue';

const MUTE_KEY = 'chatwoot_muted_conversations';

const readMutedIds = () => {
  try {
    const parsed = JSON.parse(localStorage.getItem(MUTE_KEY) || '[]');
    if (!Array.isArray(parsed)) return [];
    return parsed.map(Number).filter(Number.isFinite);
  } catch {
    return [];
  }
};

const mutedConversationIds = ref(readMutedIds());

const persistMutedIds = () => {
  localStorage.setItem(MUTE_KEY, JSON.stringify(mutedConversationIds.value));
};

export const isConversationMuted = conversationId =>
  mutedConversationIds.value.includes(Number(conversationId));

export function useMutedConversations() {
  const mutedConversations = computed(() => mutedConversationIds.value);

  const isMuted = conversationId => isConversationMuted(conversationId);

  const muteConversation = conversationId => {
    const id = Number(conversationId);
    if (!Number.isFinite(id) || mutedConversationIds.value.includes(id)) return;
    mutedConversationIds.value = [...mutedConversationIds.value, id];
    persistMutedIds();
  };

  const unmuteConversation = conversationId => {
    const id = Number(conversationId);
    mutedConversationIds.value = mutedConversationIds.value.filter(
      mutedId => mutedId !== id
    );
    persistMutedIds();
  };

  const toggleMute = conversationId => {
    if (isMuted(conversationId)) {
      unmuteConversation(conversationId);
      return;
    }
    muteConversation(conversationId);
  };

  return {
    mutedConversations,
    isMuted,
    muteConversation,
    unmuteConversation,
    toggleMute,
  };
}
