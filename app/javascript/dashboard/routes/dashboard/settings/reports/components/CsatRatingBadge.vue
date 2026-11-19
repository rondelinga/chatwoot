<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  CSAT_RATINGS,
  CSAT_DISPLAY_TYPES,
  CSAT_LIKE_DISLIKE_RATINGS,
} from 'shared/constants/messages';

const props = defineProps({
  rating: {
    type: Number,
    required: true,
  },
  displayType: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();

const ratingColor = computed(() => {
  const match = CSAT_RATINGS.find(item => item.value === props.rating);
  return match?.color || '#e5e7eb';
});

const label = computed(() => {
  const options =
    props.displayType === CSAT_DISPLAY_TYPES.LIKE_DISLIKE
      ? CSAT_LIKE_DISLIKE_RATINGS
      : CSAT_RATINGS;
  const match = options.find(item => item.value === props.rating) || {};
  return match.translationKey ? t(match.translationKey) : '';
});
</script>

<template>
  <div
    class="inline-flex items-center gap-1.5 px-2 py-1 rounded-lg"
    :style="{ backgroundColor: `${ratingColor}20` }"
  >
    <span class="text-sm font-medium text-n-slate-12 truncate">
      {{ label }}
    </span>
  </div>
</template>
