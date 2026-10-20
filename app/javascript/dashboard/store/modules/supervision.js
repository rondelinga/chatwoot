import ConversationApi from 'dashboard/api/inbox/conversation';

const SET_OPEN_CONVERSATIONS = 'SET_OPEN_CONVERSATIONS';
const UPSERT_CONVERSATION = 'UPSERT_CONVERSATION';
const REMOVE_CONVERSATION = 'REMOVE_CONVERSATION';
const SET_TYPING = 'SET_TYPING';
const CLEAR_TYPING = 'CLEAR_TYPING';
const SET_UI_FLAG = 'SET_UI_FLAG';

const moduleState = {
  openConversations: [],
  typingByUserId: {},
  uiFlags: {
    isFetching: false,
  },
};

const fetchOpenPage = async (page, seen, conversations, total) => {
  if (conversations.length >= total) return conversations;

  const { data } = await ConversationApi.get({ status: 'open', page });
  const payload = data?.data?.payload || [];
  const nextTotal = data?.data?.meta?.all_count ?? payload.length;
  const fresh = payload.filter(conversation => !seen.has(conversation.id));
  if (!fresh.length) return conversations;

  fresh.forEach(conversation => seen.add(conversation.id));
  return fetchOpenPage(page + 1, seen, conversations.concat(fresh), nextTotal);
};

export const getters = {
  getOpenConversations($state) {
    return $state.openConversations;
  },
  getTypingByUserId($state) {
    return $state.typingByUserId;
  },
  getUIFlags($state) {
    return $state.uiFlags;
  },
};

export const actions = {
  refreshOpenConversations: async ({ commit }) => {
    commit(SET_UI_FLAG, { isFetching: true });
    try {
      const conversations = await fetchOpenPage(1, new Set(), [], Infinity);
      commit(SET_OPEN_CONVERSATIONS, conversations);
    } finally {
      commit(SET_UI_FLAG, { isFetching: false });
    }
  },

  applyRealtime: ({ commit, state }, { event, data }) => {
    if (!data) return;

    if (event === 'conversation.typing_on') {
      const user = data.user;
      if (user?.type !== 'user' || !user.id) return;
      commit(SET_TYPING, {
        userId: user.id,
        conversationId: data.conversation?.id,
        user,
        text: state.typingByUserId[user.id]?.text || '',
      });
      return;
    }

    if (event === 'conversation.typing_off') {
      if (data.user?.type !== 'user') return;
      commit(CLEAR_TYPING, data.user.id);
      return;
    }

    if (event === 'conversation.supervisor_typing') {
      const user = data.user;
      if (!user?.id) return;
      commit(SET_TYPING, {
        userId: user.id,
        conversationId: data.conversation_id,
        user,
        text: data.text || '',
      });
      return;
    }

    if (event === 'message.created') {
      if (data.sender?.type === 'user') commit(CLEAR_TYPING, data.sender.id);
      return;
    }

    if (
      event === 'conversation.created' ||
      event === 'conversation.status_changed' ||
      event === 'assignee.changed' ||
      event === 'conversation.updated'
    ) {
      if (data.status && data.status !== 'open') {
        commit(REMOVE_CONVERSATION, data.id);
        return;
      }
      if (data.id) commit(UPSERT_CONVERSATION, data);
    }
  },
};

export const mutations = {
  [SET_OPEN_CONVERSATIONS]($state, conversations) {
    $state.openConversations = conversations;
  },
  [UPSERT_CONVERSATION]($state, conversation) {
    const index = $state.openConversations.findIndex(
      item => item.id === conversation.id
    );
    if (index === -1) {
      $state.openConversations.push(conversation);
      return;
    }
    $state.openConversations.splice(index, 1, {
      ...$state.openConversations[index],
      ...conversation,
    });
  },
  [REMOVE_CONVERSATION]($state, conversationId) {
    $state.openConversations = $state.openConversations.filter(
      conversation => conversation.id !== conversationId
    );
  },
  [SET_TYPING]($state, { userId, conversationId, user, text }) {
    $state.typingByUserId = {
      ...$state.typingByUserId,
      [userId]: { conversationId, user, text },
    };
  },
  [CLEAR_TYPING]($state, userId) {
    const next = { ...$state.typingByUserId };
    delete next[userId];
    $state.typingByUserId = next;
  },
  [SET_UI_FLAG]($state, flags) {
    $state.uiFlags = { ...$state.uiFlags, ...flags };
  },
};

export default {
  namespaced: true,
  state: moduleState,
  getters,
  actions,
  mutations,
};
