<script setup>
import { computed } from 'vue';
import Icon from 'next/icon/Icon.vue';
import * as Sentry from '@sentry/vue';
import FormSelect from 'v3/components/Form/Select.vue';
import {
  BUILTIN_ALERT_TONES,
  playAlertSound,
} from 'dashboard/helper/AudioAlerts/AudioNotificationService';

const props = defineProps({
  value: {
    type: String,
    required: true,
  },
  label: {
    type: String,
    default: '',
  },
  extraOptions: {
    type: Array,
    default: () => [],
  },
  playSrc: {
    type: String,
    default: '',
  },
  volume: {
    type: Number,
    default: 80,
  },
});

const emit = defineEmits(['change']);

const alertTones = computed(() => [
  ...BUILTIN_ALERT_TONES,
  ...props.extraOptions,
]);

const selectedValue = computed({
  get: () => props.value,
  set: value => {
    emit('change', value);
  },
});

const playAudio = async () => {
  try {
    await playAlertSound({
      tone: selectedValue.value,
      customUrl: props.playSrc,
      volume: props.volume,
    });
  } catch (error) {
    Sentry.captureException(error);
  }
};
</script>

<template>
  <div class="flex items-center gap-2">
    <FormSelect
      v-model="selectedValue"
      name="alertTone"
      spacing="compact"
      class="flex-grow"
      :value="selectedValue"
      :options="alertTones"
      :label="label"
    >
      <option
        v-for="tone in alertTones"
        :key="tone.value"
        :value="tone.value"
        :selected="tone.value === selectedValue"
      >
        {{ tone.label }}
      </option>
    </FormSelect>
    <button
      v-tooltip.top="
        $t('PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION.PLAY')
      "
      type="button"
      class="border-0 shadow-sm outline-none flex justify-center items-center size-10 appearance-none rounded-xl ring-n-weak ring-1 ring-inset focus:ring-2 focus:ring-inset focus:ring-n-brand flex-shrink-0 mt-[1.75rem]"
      @click="playAudio"
    >
      <Icon icon="i-lucide-volume-2" />
    </button>
  </div>
</template>
