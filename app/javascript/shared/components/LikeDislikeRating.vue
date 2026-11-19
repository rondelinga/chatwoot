<script setup>
import { CSAT_LIKE_DISLIKE_RATINGS } from 'shared/constants/messages';

defineProps({
  selectedRating: {
    type: Number,
    default: null,
  },
  isDisabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['selectRating']);
</script>

<template>
  <div class="flex justify-center gap-6 py-5 px-4 text-2xl">
    <button
      v-for="rating in CSAT_LIKE_DISLIKE_RATINGS"
      :key="rating.key"
      type="button"
      class="grayscale outline-none transition-all duration-200 hover:grayscale-0 hover:scale-[1.32] focus:grayscale-0 focus:scale-[1.32] disabled:cursor-not-allowed disabled:opacity-50"
      :class="{ '!grayscale-0 scale-[1.32]': selectedRating === rating.value }"
      :disabled="isDisabled"
      @click="emit('selectRating', rating.value)"
    >
      {{ rating.emoji }}
    </button>
  </div>
</template>
