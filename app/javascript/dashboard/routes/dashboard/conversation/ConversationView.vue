<script>
import { provide } from 'vue';
import { mapGetters } from 'vuex';
import { useUISettings } from 'dashboard/composables/useUISettings';
import {
  CONTACT_CONVERSATION_NAVIGATION,
  useContactConversationNavigation,
} from 'dashboard/composables/useContactConversationNavigation';
import { useAccount } from 'dashboard/composables/useAccount';
import ChatList from '../../../components/ChatList.vue';
import ConversationBox from '../../../components/widgets/conversation/ConversationBox.vue';
import wootConstants from 'dashboard/constants/globals';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import CmdBarConversationSnooze from 'dashboard/routes/dashboard/commands/CmdBarConversationSnooze.vue';
import { emitter } from 'shared/helpers/mitt';
import SidepanelSwitch from 'dashboard/components-next/Conversation/SidepanelSwitch.vue';
import ConversationSidebar from 'dashboard/components/widgets/conversation/ConversationSidebar.vue';

export default {
  components: {
    ChatList,
    ConversationBox,
    CmdBarConversationSnooze,
    SidepanelSwitch,
    ConversationSidebar,
  },
  beforeRouteLeave(to, from, next) {
    // Clear selected state if navigating away from a conversation to a route without a conversationId to prevent stale data issues
    // and resolves timing issues during navigation with conversation view and other screens
    if (this.conversationId) {
      this.$store.dispatch('clearSelectedState');
    }
    next(); // Continue with navigation
  },
  props: {
    inboxId: {
      type: [String, Number],
      default: 0,
    },
    conversationId: {
      type: [String, Number],
      default: 0,
    },
    label: {
      type: String,
      default: '',
    },
    teamId: {
      type: String,
      default: '',
    },
    conversationType: {
      type: String,
      default: '',
    },
    foldersId: {
      type: [String, Number],
      default: 0,
    },
    agentId: {
      type: [String, Number],
      default: 0,
    },
  },
  setup() {
    const { uiSettings, updateUISettings, isOnExpandedLayout } =
      useUISettings();
    const { accountId } = useAccount();
    provide(
      CONTACT_CONVERSATION_NAVIGATION,
      useContactConversationNavigation()
    );

    return {
      uiSettings,
      updateUISettings,
      isOnExpandedLayout,
      accountId,
    };
  },
  data() {
    return {
      showSearchModal: false,
      superviseTab: this.conversationId ? 'chat' : 'chats',
    };
  },
  computed: {
    ...mapGetters({
      chatList: 'getAllConversations',
      currentChat: 'getSelectedChat',
    }),
    showConversationList() {
      return this.isOnExpandedLayout ? !this.conversationId : true;
    },
    showMessageView() {
      return this.conversationId ? true : !this.isOnExpandedLayout;
    },
    shouldShowSidebar() {
      if (!this.currentChat.id) {
        return false;
      }

      const { is_contact_sidebar_open: isContactSidebarOpen } = this.uiSettings;
      return isContactSidebarOpen;
    },
    agentChatCount() {
      const agentId = Number(this.agentId);
      if (!agentId) return 0;

      const conversations =
        this.$store.getters['supervision/getOpenConversations'] || [];
      return conversations.filter(conversation => {
        const assigneeType = conversation.meta?.assignee_type;
        const isHumanAssignee = !assigneeType || assigneeType === 'User';
        return isHumanAssignee && conversation.meta?.assignee?.id === agentId;
      }).length;
    },
    superviseTabs() {
      return [
        { key: 'chat', label: this.$t('SUPERVISION.CHAT_TAB') },
        {
          key: 'chats',
          label: this.$t('SUPERVISION.AGENT_CHATS_TAB', {
            count: this.agentChatCount,
          }),
        },
      ];
    },
  },
  watch: {
    conversationId(id) {
      this.fetchConversationIfUnavailable();
      if (!this.agentId) return;
      this.superviseTab = id ? 'chat' : 'chats';
    },
  },

  created() {
    // Clear selected state early if no conversation is selected
    // This prevents child components from accessing stale data
    // and resolves timing issues during navigation
    // with conversation view and other screens
    if (!this.conversationId) {
      this.$store.dispatch('clearSelectedState');
    }
  },

  mounted() {
    this.$store.dispatch('agents/get');
    this.$store.dispatch('portals/index');
    this.initialize();
    this.$watch('$store.state.route', () => this.initialize());
    this.$watch('chatList.length', () => {
      this.setActiveChat();
    });
  },

  methods: {
    onConversationLoad() {
      this.fetchConversationIfUnavailable();
    },
    initialize() {
      this.$store.dispatch('setActiveInbox', this.inboxId);
      this.setActiveChat();
    },
    toggleConversationLayout() {
      const { LAYOUT_TYPES } = wootConstants;
      const {
        conversation_display_type:
          conversationDisplayType = LAYOUT_TYPES.CONDENSED,
      } = this.uiSettings;
      const newViewType =
        conversationDisplayType === LAYOUT_TYPES.CONDENSED
          ? LAYOUT_TYPES.EXPANDED
          : LAYOUT_TYPES.CONDENSED;
      this.updateUISettings({
        conversation_display_type: newViewType,
        previously_used_conversation_display_type: newViewType,
      });
    },
    fetchConversationIfUnavailable() {
      if (!this.conversationId) {
        return;
      }
      const chat = this.findConversation();
      if (!chat) {
        this.$store.dispatch('getConversation', this.conversationId);
      }
    },
    findConversation() {
      const conversationId = parseInt(this.conversationId, 10);
      const [chat] = this.chatList.filter(c => c.id === conversationId);
      return chat;
    },
    setActiveChat() {
      if (this.conversationId) {
        const selectedConversation = this.findConversation();
        // If conversation doesn't exist or selected conversation is same as the active
        // conversation, don't set active conversation.
        if (
          !selectedConversation ||
          selectedConversation.id === this.currentChat.id
        ) {
          return;
        }
        const { messageId } = this.$route.query;
        this.$store
          .dispatch('setActiveChat', {
            data: selectedConversation,
            after: messageId,
          })
          .then(() => {
            emitter.emit(BUS_EVENTS.SCROLL_TO_MESSAGE, { messageId });
          });
      } else {
        this.$store.dispatch('clearSelectedState');
      }
    },
    onSearch() {
      this.showSearchModal = true;
    },
    closeSearch() {
      this.showSearchModal = false;
    },
  },
};
</script>

<template>
  <section v-if="agentId" class="flex h-full min-h-0 w-full min-w-0 flex-col">
    <div class="flex shrink-0 gap-1 border-b border-n-weak px-4">
      <button
        v-for="tab in superviseTabs"
        :key="tab.key"
        type="button"
        class="border-b-2 px-3 py-3 text-sm"
        :class="
          superviseTab === tab.key
            ? 'border-n-brand text-n-slate-12'
            : 'border-transparent text-n-slate-11'
        "
        @click="superviseTab = tab.key"
      >
        {{ tab.label }}
      </button>
    </div>
    <div class="flex min-h-0 flex-1">
      <ChatList
        v-show="superviseTab === 'chats'"
        fluid
        :conversation-inbox="inboxId"
        :agent-id="agentId"
        :is-on-expanded-layout="false"
        @conversation-load="onConversationLoad"
      />
      <ConversationBox
        v-show="superviseTab === 'chat'"
        :inbox-id="inboxId"
        :is-on-expanded-layout="false"
      >
        <SidepanelSwitch v-if="currentChat.id" />
      </ConversationBox>
      <ConversationSidebar
        v-if="superviseTab === 'chat' && shouldShowSidebar"
        :current-chat="currentChat"
      />
    </div>
    <CmdBarConversationSnooze />
  </section>
  <section v-else class="flex w-full h-full min-w-0">
    <ChatList
      :show-conversation-list="showConversationList"
      :conversation-inbox="inboxId"
      :label="label"
      :team-id="teamId"
      :conversation-type="conversationType"
      :folders-id="foldersId"
      :agent-id="agentId"
      :is-on-expanded-layout="isOnExpandedLayout"
      @conversation-load="onConversationLoad"
    />
    <ConversationBox
      v-if="showMessageView"
      :inbox-id="inboxId"
      :is-on-expanded-layout="isOnExpandedLayout"
    >
      <SidepanelSwitch v-if="currentChat.id" />
    </ConversationBox>
    <ConversationSidebar v-if="shouldShowSidebar" :current-chat="currentChat" />
    <CmdBarConversationSnooze />
  </section>
</template>
