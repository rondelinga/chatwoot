<script setup>
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  message: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['dismiss']);
</script>

<template>
  <div
    class="bg-n-slate-9/10 rounded-md py-1 ps-2 pe-1 text-xs tracking-wide mt-2 flex items-center gap-1.5"
  >
    <fluent-icon class="flex-shrink-0" icon="edit" size="14" />
    <div class="flex-grow mt-px text-xs truncate">
      {{ $t('EDIT_MESSAGE.TITLE') }}
      <span class="text-n-slate-11">{{ message }}</span>
    </div>
    <Button
      ghost
      xs
      slate
      icon="i-lucide-x"
      class="flex-shrink-0"
      @click.stop="emit('dismiss')"
    />
  </div>
</template>
