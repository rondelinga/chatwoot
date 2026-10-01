<script setup>
import { useAlert } from 'dashboard/composables';
import { useUISettings } from 'dashboard/composables/useUISettings';
import AudioAlertEvent from './AudioAlertEvent.vue';
import AudioAlertCondition from './AudioAlertCondition.vue';
import NotificationEventSound from './NotificationEventSound.vue';
import NotificationSoundUploader from './NotificationSoundUploader.vue';
import { computed, onMounted, ref, watch } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import camelcaseKeys from 'camelcase-keys';
import { initializeAudioAlerts } from 'dashboard/helper/scriptHelpers';

const store = useStore();
const currentUser = useMapGetter('getCurrentUser');
const soundSettings = useMapGetter('userNotificationSettings/getSoundSettings');

const { uiSettings, updateUISettings } = useUISettings();
const { t } = useI18n();

const audioAlert = ref('');
const playAudioWhenTabIsInactive = ref(false);
const alertIfUnreadConversationExist = ref(false);
const audioAlertConditions = ref([]);
const conversationSoundEnabled = ref(true);
const conversationSound = ref('bell');
const messageSoundEnabled = ref(true);
const messageSound = ref('pop');
const i18nKeyPrefix = 'PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION';

const customSoundOptions = computed(() =>
  (soundSettings.value.custom_sounds || []).map(sound => ({
    value: `custom-${sound.id}`,
    label: sound.filename,
    url: sound.url,
  }))
);

const selectedSoundPlaySrc = (selectedValue, fallbackUrl) => {
  if (!selectedValue?.startsWith('custom-')) return '';
  const option = customSoundOptions.value.find(
    sound => sound.value === selectedValue
  );
  return option?.url || fallbackUrl || '';
};

const conversationPlaySrc = computed(() =>
  selectedSoundPlaySrc(
    conversationSound.value,
    soundSettings.value.new_conversation_custom_sound_url
  )
);
const messagePlaySrc = computed(() =>
  selectedSoundPlaySrc(
    messageSound.value,
    soundSettings.value.new_message_custom_sound_url
  )
);

const soundValueFromSettings = (soundName, customSoundId, fallback) => {
  if (customSoundId) return `custom-${customSoundId}`;
  if (soundName && soundName !== 'custom') return soundName;
  return fallback;
};

const payloadFromSoundValue = (selectedValue, defaultTone) => {
  if (selectedValue?.startsWith('custom-')) {
    return {
      sound: 'custom',
      customSoundId: Number(selectedValue.replace('custom-', '')),
    };
  }
  return {
    sound: selectedValue || defaultTone,
    customSoundId: null,
  };
};

const initializeNotificationUISettings = newUISettings => {
  const updatedUISettings = camelcaseKeys(newUISettings);

  audioAlert.value = updatedUISettings.enableAudioAlerts;
  playAudioWhenTabIsInactive.value = !updatedUISettings.alwaysPlayAudioAlert;
  alertIfUnreadConversationExist.value =
    updatedUISettings.alertIfUnreadAssignedConversationExist;
  audioAlertConditions.value = [
    {
      id: 'audio1',
      label: t(`${i18nKeyPrefix}.CONDITIONS.CONDITION_ONE`),
      model: playAudioWhenTabIsInactive.value,
      value: 'tab_is_inactive',
    },
    {
      id: 'audio2',
      label: t(`${i18nKeyPrefix}.CONDITIONS.CONDITION_TWO`),
      model: alertIfUnreadConversationExist.value,
      value: 'conversations_are_read',
    },
  ];
};

const initializeSoundSettings = () => {
  conversationSoundEnabled.value =
    soundSettings.value.new_conversation_sound_enabled;
  conversationSound.value = soundValueFromSettings(
    soundSettings.value.new_conversation_sound,
    soundSettings.value.new_conversation_custom_sound_id,
    'bell'
  );
  messageSoundEnabled.value = soundSettings.value.new_message_sound_enabled;
  messageSound.value = soundValueFromSettings(
    soundSettings.value.new_message_sound,
    soundSettings.value.new_message_custom_sound_id,
    'pop'
  );
};

watch(
  uiSettings,
  value => {
    initializeNotificationUISettings(value);
  },
  { immediate: true }
);

watch(
  soundSettings,
  () => {
    initializeSoundSettings();
  },
  { immediate: true, deep: true }
);

const handleAudioConfigChange = value => {
  updateUISettings(value);
  initializeAudioAlerts(currentUser.value);
  useAlert(t('PROFILE_SETTINGS.FORM.API.UPDATE_SUCCESS'));
};

const updateSoundSettings = async payload => {
  try {
    await store.dispatch('userNotificationSettings/update', payload);
    initializeAudioAlerts(currentUser.value);
    useAlert(t('PROFILE_SETTINGS.FORM.API.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(t('PROFILE_SETTINGS.FORM.API.UPDATE_ERROR'));
  }
};

onMounted(() => {
  store.dispatch('userNotificationSettings/get');
});

const handAudioAlertChange = value => {
  audioAlert.value = value;
  handleAudioConfigChange({
    enable_audio_alerts: value,
  });
};
const handleAudioAlertConditions = (id, value) => {
  if (id === 'tab_is_inactive') {
    handleAudioConfigChange({
      always_play_audio_alert: !value,
    });
  } else if (id === 'conversations_are_read') {
    handleAudioConfigChange({
      alert_if_unread_assigned_conversation_exist: value,
    });
  }
};

const handleConversationEnabledChange = value => {
  conversationSoundEnabled.value = value;
  updateSoundSettings({ new_conversation_sound_enabled: value });
};

const handleMessageEnabledChange = value => {
  messageSoundEnabled.value = value;
  updateSoundSettings({ new_message_sound_enabled: value });
};

const handleConversationSoundChange = value => {
  conversationSound.value = value;
  const { sound, customSoundId } = payloadFromSoundValue(value, 'bell');
  updateSoundSettings({
    new_conversation_sound: sound,
    new_conversation_custom_sound_id: customSoundId,
  });
};

const handleMessageSoundChange = value => {
  messageSound.value = value;
  const { sound, customSoundId } = payloadFromSoundValue(value, 'pop');
  updateSoundSettings({
    new_message_sound: sound,
    new_message_custom_sound_id: customSoundId,
  });
};

const refreshSoundSettings = () => {
  store.dispatch('userNotificationSettings/get');
};

const onCustomSoundDeleted = soundId => {
  if (conversationSound.value === `custom-${soundId}`) {
    conversationSound.value = 'bell';
  }
  if (messageSound.value === `custom-${soundId}`) {
    messageSound.value = 'pop';
  }
  refreshSoundSettings();
};
</script>

<template>
  <div id="profile-settings-notifications" class="flex flex-col gap-6">
    <NotificationSoundUploader
      :sounds="soundSettings.custom_sounds"
      @uploaded="refreshSoundSettings"
      @deleted="onCustomSoundDeleted"
    />

    <NotificationEventSound
      :label="$t(`${i18nKeyPrefix}.NEW_CONVERSATION.TITLE`)"
      :enabled="conversationSoundEnabled"
      :sound="conversationSound"
      :extra-options="customSoundOptions"
      :play-src="conversationPlaySrc"
      :volume="soundSettings.new_conversation_volume"
      @update:enabled="handleConversationEnabledChange"
      @update:sound="handleConversationSoundChange"
    />

    <NotificationEventSound
      :label="$t(`${i18nKeyPrefix}.NEW_MESSAGE.TITLE`)"
      :sound="messageSound"
      :enabled="messageSoundEnabled"
      :extra-options="customSoundOptions"
      :play-src="messagePlaySrc"
      :volume="soundSettings.new_message_volume"
      @update:enabled="handleMessageEnabledChange"
      @update:sound="handleMessageSoundChange"
    />

    <AudioAlertEvent
      :label="$t(`${i18nKeyPrefix}.ALERT_TYPE.TITLE`)"
      :value="audioAlert"
      @update="handAudioAlertChange"
    />

    <AudioAlertCondition
      :items="audioAlertConditions"
      :label="$t(`${i18nKeyPrefix}.CONDITIONS.TITLE`)"
      @change="handleAudioAlertConditions"
    />
  </div>
</template>
