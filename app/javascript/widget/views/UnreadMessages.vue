<script>
import { mapGetters } from 'vuex';
import { IFrameHelper } from 'widget/helpers/utils';
import UnreadMessageList from '../components/UnreadMessageList.vue';
import OutboundNotification from '../components/OutboundNotification.vue';

export default {
  name: 'UnreadMessages',
  components: {
    UnreadMessageList,
    OutboundNotification,
  },
  computed: {
    ...mapGetters({
      messages: 'conversation/getUnreadTextMessages',
      latestOutgoingMessage: 'conversation/getLatestOutgoingMessage',
      showOutboundNotification: 'conversation/getShowOutboundNotification',
    }),
    showOutboundCard() {
      return (
        this.showOutboundNotification &&
        (this.messages.length > 0 || Boolean(this.latestOutgoingMessage?.id))
      );
    },
  },
  methods: {
    closeFullView() {
      this.$store.dispatch('conversation/setShowOutboundNotification', false);
      if (IFrameHelper.isIFrame()) {
        IFrameHelper.sendMessage({ event: 'toggleBubble' });
      }
    },
  },
};
</script>

<template>
  <OutboundNotification v-if="showOutboundCard" @close="closeFullView" />
  <UnreadMessageList
    v-else-if="messages.length"
    :messages="messages"
    @close="closeFullView"
  />
</template>
