<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Avatar from 'next/avatar/Avatar.vue';

const props = defineProps({
  agent: { type: Object, required: true },
  chatCount: { type: Number, default: 0 },
  isTyping: { type: Boolean, default: false },
  isSelected: { type: Boolean, default: false },
});

const emit = defineEmits(['select']);
const { t } = useI18n();

const status = computed(() => props.agent.availability_status || 'offline');
</script>

<template>
  <button
    type="button"
    class="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-start hover:bg-n-alpha-2"
    :class="{ 'bg-n-brand/10': isSelected }"
    @click="emit('select', agent.id)"
  >
    <Avatar
      :name="agent.name"
      :src="agent.thumbnail"
      :size="32"
      :status="status"
      rounded-full
    />
    <span class="min-w-0 flex-1">
      <span class="flex items-center gap-1">
        <span class="truncate text-sm text-n-slate-12">{{ agent.name }}</span>
        <span
          v-if="isTyping"
          class="relative flex size-2 shrink-0"
          :title="t('SUPERVISION.TYPING_PREVIEW', { name: agent.name })"
        >
          <span
            class="absolute inline-flex size-full animate-ping rounded-full bg-n-teal-10 opacity-75"
          />
          <span class="relative inline-flex size-2 rounded-full bg-n-teal-10" />
        </span>
      </span>
      <span class="text-xs text-n-slate-11">
        {{ chatCount }} {{ t('SUPERVISION.CHATS') }}
      </span>
    </span>
  </button>
</template>
