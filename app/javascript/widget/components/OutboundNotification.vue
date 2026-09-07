<script setup>
import { computed, onMounted, onUnmounted } from 'vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { ON_UNREAD_MESSAGE_CLICK } from '../constants/widgetBusEvents';
import { isEmptyObject } from 'widget/helpers/utils';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { emitter } from 'shared/helpers/mitt';

const emit = defineEmits(['close']);

const AUTO_HIDE_MS = 15000;
const PREVIEW_LENGTH = 80;

const store = useStore();
const { t } = useI18n();

const unreadMessages = useMapGetter('conversation/getUnreadTextMessages');
const latestMessage = computed(() => {
  const messages = unreadMessages.value || [];
  return messages[messages.length - 1] || {};
});
const sender = computed(() => latestMessage.value.sender || {});
const agentName = computed(() => {
  if (!sender.value || isEmptyObject(sender.value)) {
    return t('OUTBOUND_NOTIFICATION.MANAGER');
  }
  return (
    sender.value.available_name ||
    sender.value.name ||
    t('OUTBOUND_NOTIFICATION.MANAGER')
  );
});
const agentAvatar = computed(
  () => sender.value.avatar_url || sender.value.thumbnail || ''
);
const preview = computed(() => {
  const content = latestMessage.value.content || '';
  if (content.length <= PREVIEW_LENGTH) return content;
  return `${content.slice(0, PREVIEW_LENGTH)}…`;
});

let hideTimer = null;

const clearTimer = () => {
  if (hideTimer) {
    clearTimeout(hideTimer);
    hideTimer = null;
  }
};

const reply = () => {
  clearTimer();
  store.dispatch('conversation/setShowOutboundNotification', false);
  emitter.emit(ON_UNREAD_MESSAGE_CLICK);
};

const closeNotification = () => {
  clearTimer();
  emit('close');
};

onMounted(() => {
  hideTimer = setTimeout(() => {
    closeNotification();
  }, AUTO_HIDE_MS);
});

onUnmounted(() => {
  clearTimer();
});
</script>

<template>
  <div class="unread-wrap unread-messages outbound-notification" dir="ltr">
    <div
      class="flex flex-col w-full max-w-xs gap-3 p-4 ml-auto bg-n-background shadow-lg rounded-xl"
    >
      <div class="flex items-start justify-between gap-2">
        <div class="flex items-center min-w-0 gap-2">
          <Avatar
            :src="agentAvatar"
            :size="24"
            :name="agentName"
            rounded-full
          />
          <span class="text-sm font-medium truncate text-n-slate-12">
            {{ agentName }}
          </span>
        </div>
        <button
          type="button"
          class="flex items-center justify-center text-n-slate-10 hover:text-n-slate-12"
          :aria-label="t('OUTBOUND_NOTIFICATION.CLOSE')"
          @click="closeNotification"
        >
          <span class="i-lucide-x size-4" />
        </button>
      </div>
      <p class="mb-0 text-sm break-words text-n-slate-12">
        {{ preview }}
      </p>
      <button
        type="button"
        class="w-full px-3 py-2 text-sm font-medium text-white rounded-lg bg-n-brand"
        @click="reply"
      >
        {{ t('OUTBOUND_NOTIFICATION.REPLY') }}
      </button>
    </div>
  </div>
</template>
