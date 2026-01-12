<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

const emit = defineEmits(['timeRangeChanged']);
const { t } = useI18n();
const timeFrom = ref('00:00');
const timeTo = ref('23:59');

watch(
  [timeFrom, timeTo],
  () => {
    emit('timeRangeChanged', {
      since: timeFrom.value,
      until: timeTo.value,
    });
  },
  { immediate: true }
);
</script>

<template>
  <div class="flex items-center gap-1">
    <input
      v-model="timeFrom"
      type="time"
      class="px-2 py-1 rounded text-sm time-input"
    />

    <span class="text-n-slate-10 text-sm">{{
      t('AGENT_ACTIVITY_REPORTS.FILTERS.TIME_RANGE_SEPARATOR')
    }}</span>

    <input
      v-model="timeTo"
      type="time"
      class="px-2 py-1 rounded text-sm time-input"
    />
  </div>
</template>

<style scoped>
.time-input {
  margin-bottom: 0;
  background-color: rgba(var(--alpha-2));
  height: 2rem;
  min-width: 80px;
}
</style>
