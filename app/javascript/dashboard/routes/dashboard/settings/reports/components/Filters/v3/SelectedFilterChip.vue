<script setup>
defineProps({
  name: {
    type: String,
    required: true,
  },
});

defineEmits(['remove']);
</script>

<template>
  <button
    type="button"
    class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-full bg-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-3 transition-colors"
    @click="$emit('remove')"
  >
    <span class="truncate">{{ name }}</span>
    <span class="i-lucide-x size-4 flex-shrink-0" />
  </button>
</template>
