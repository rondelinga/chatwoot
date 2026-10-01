import { useAlert } from 'dashboard/composables';
import { isConversationMuted } from 'dashboard/composables/useMutedConversations';

const ALERT_DURATION = 10000;
const ALERT_PATH_PREFIX = '/audio/dashboard/';
const TONE_FILES = { pop: 'ping' };

export const BUILTIN_ALERT_TONES = [
  { value: 'ding', label: 'Ding' },
  { value: 'bell', label: 'Bell' },
  { value: 'chime', label: 'Chime' },
  { value: 'magic', label: 'Magic' },
  { value: 'ping', label: 'Ping' },
  { value: 'pop', label: 'Pop' },
];

export const getBuiltinSoundUrl = (tone = 'ding') => {
  const isCustom = !tone || tone === 'custom' || tone.startsWith('custom-');
  const normalizedTone = isCustom ? 'ding' : tone;
  const fileName = TONE_FILES[normalizedTone] || normalizedTone || 'ding';
  return `${ALERT_PATH_PREFIX}${fileName}.mp3`;
};

export const playAlertSound = ({ tone, customUrl, volume = 80 } = {}) => {
  const audio = new Audio(customUrl || getBuiltinSoundUrl(tone));
  const normalizedVolume = Number(volume);
  audio.volume = Math.min(
    1,
    Math.max(
      0,
      Number.isFinite(normalizedVolume) ? normalizedVolume / 100 : 0.8
    )
  );
  return audio.play();
};

export class AudioNotificationService {
  constructor(getSettings) {
    this.getSettings = getSettings;
    this.hasSentSoundPermissionsRequest = false;
  }

  playNewConversation() {
    const settings = this.getSettings() || {};
    if (settings.new_conversation_sound_enabled === false)
      return Promise.resolve();

    return this.play({
      tone: settings.new_conversation_sound || 'bell',
      customUrl: settings.new_conversation_custom_sound_url,
      volume: settings.new_conversation_volume ?? 80,
    });
  }

  playNewMessage(conversationId) {
    const settings = this.getSettings() || {};
    if (settings.new_message_sound_enabled === false) return Promise.resolve();
    if (conversationId && isConversationMuted(conversationId)) {
      return Promise.resolve();
    }

    return this.play({
      tone: settings.new_message_sound || 'pop',
      customUrl: settings.new_message_custom_sound_url,
      volume: settings.new_message_volume ?? 60,
    });
  }

  async play({ tone, customUrl, volume }) {
    try {
      await playAlertSound({ tone, customUrl, volume });
    } catch (error) {
      if (
        error.name === 'NotAllowedError' &&
        !this.hasSentSoundPermissionsRequest
      ) {
        this.hasSentSoundPermissionsRequest = true;
        useAlert(
          'PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION.SOUND_PERMISSION_ERROR',
          { usei18n: true, duration: ALERT_DURATION }
        );
      }
    }
  }
}
