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
      showOutboundNotification: 'conversation/getShowOutboundNotification',
    }),
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
  <OutboundNotification
    v-if="showOutboundNotification && messages.length"
    @close="closeFullView"
  />
  <UnreadMessageList
    v-else-if="messages.length"
    :messages="messages"
    @close="closeFullView"
  />
</template>
