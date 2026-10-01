<script setup>
import { computed } from 'vue';
import ToggleSwitch from 'dashboard/components-next/switch/Switch.vue';
import AudioAlertTone from './AudioAlertTone.vue';

const props = defineProps({
  label: {
    type: String,
    required: true,
  },
  enabled: {
    type: Boolean,
    default: true,
  },
  sound: {
    type: String,
    required: true,
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

const emit = defineEmits(['update:enabled', 'update:sound']);

const enabledModel = computed({
  get: () => props.enabled,
  set: value => emit('update:enabled', value),
});
</script>

<template>
  <div class="flex flex-col gap-3">
    <div class="flex items-center justify-between gap-3">
      <span class="text-sm font-medium text-n-slate-12">{{ label }}</span>
      <ToggleSwitch v-model="enabledModel" />
    </div>
    <AudioAlertTone
      v-if="enabled"
      :value="sound"
      :label="
        $t('PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION.SOUND_LABEL')
      "
      :extra-options="extraOptions"
      :play-src="playSrc"
      :volume="volume"
      @change="value => emit('update:sound', value)"
    />
  </div>
</template>
