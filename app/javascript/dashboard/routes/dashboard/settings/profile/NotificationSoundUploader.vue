<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import * as Sentry from '@sentry/vue';
import Icon from 'next/icon/Icon.vue';
import ButtonV4 from 'dashboard/components-next/button/Button.vue';
import NotificationSoundsAPI from 'dashboard/api/notificationSounds';
import { playAlertSound } from 'dashboard/helper/AudioAlerts/AudioNotificationService';

const props = defineProps({
  sounds: {
    type: Array,
    default: () => [],
  },
});
const emit = defineEmits(['uploaded', 'deleted']);
const MAX_SIZE_BYTES = 2 * 1024 * 1024;
const MAX_DURATION_SECONDS = 5;
const ALLOWED_EXTENSIONS = ['mp3', 'wav', 'ogg'];

const { t } = useI18n();
const fileInput = ref(null);
const isUploading = ref(false);
const isDragOver = ref(false);
const i18nKeyPrefix = 'PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION';

const formatFileSize = bytes => {
  if (!bytes) return '0 B';
  if (bytes < 1024) return `${bytes} B`;
  return `${(bytes / 1024).toFixed(1)} KB`;
};

const fileExtension = file =>
  (file?.name || '').split('.').pop()?.toLowerCase() || '';

const readAudioDuration = file =>
  new Promise(resolve => {
    const objectUrl = URL.createObjectURL(file);
    const audio = new Audio();
    audio.preload = 'metadata';
    audio.onloadedmetadata = () => {
      const duration = audio.duration;
      URL.revokeObjectURL(objectUrl);
      resolve(Number.isFinite(duration) ? duration : null);
    };
    audio.onerror = () => {
      URL.revokeObjectURL(objectUrl);
      resolve(null);
    };
    audio.src = objectUrl;
  });

const validateFile = async file => {
  if (!ALLOWED_EXTENSIONS.includes(fileExtension(file))) {
    useAlert(t(`${i18nKeyPrefix}.SOUNDS.INVALID_TYPE`));
    return false;
  }
  if (file.size > MAX_SIZE_BYTES) {
    useAlert(t(`${i18nKeyPrefix}.SOUNDS.TOO_LARGE`));
    return false;
  }
  const duration = await readAudioDuration(file);
  if (duration && duration > MAX_DURATION_SECONDS) {
    useAlert(t(`${i18nKeyPrefix}.SOUNDS.TOO_LONG`));
    return false;
  }
  return true;
};

const uploadFile = async file => {
  if (!file || isUploading.value) return;
  const isValid = await validateFile(file);
  if (!isValid) return;

  isUploading.value = true;
  try {
    const response = await NotificationSoundsAPI.create(file);
    emit('uploaded', response.data);
    useAlert(t(`${i18nKeyPrefix}.SOUNDS.UPLOAD_SUCCESS`));
  } catch (error) {
    useAlert(
      error?.response?.data?.error || t(`${i18nKeyPrefix}.SOUNDS.UPLOAD_ERROR`)
    );
  } finally {
    isUploading.value = false;
    if (fileInput.value) fileInput.value.value = '';
  }
};

const onFileChange = event => {
  const [file] = event.target.files || [];
  uploadFile(file);
};

const onDrop = event => {
  isDragOver.value = false;
  const [file] = event.dataTransfer?.files || [];
  uploadFile(file);
};

const playSound = async sound => {
  try {
    await playAlertSound({ customUrl: sound.url, volume: 80 });
  } catch (error) {
    Sentry.captureException(error);
  }
};

const deleteSound = async sound => {
  try {
    await NotificationSoundsAPI.delete(sound.id);
    emit('deleted', sound.id);
    useAlert(t(`${i18nKeyPrefix}.SOUNDS.DELETE_SUCCESS`));
  } catch (error) {
    useAlert(t(`${i18nKeyPrefix}.SOUNDS.DELETE_ERROR`));
  }
};

const uploadedSounds = computed(() => props.sounds);
</script>

<template>
  <div class="flex flex-col gap-3">
    <div>
      <h4 class="text-sm font-medium text-n-slate-12">
        {{ $t(`${i18nKeyPrefix}.SOUNDS.UPLOAD_TITLE`) }}
      </h4>
      <p class="mt-1 text-sm text-n-slate-11">
        {{ $t(`${i18nKeyPrefix}.SOUNDS.UPLOAD_HINT`) }}
      </p>
    </div>

    <label
      class="flex items-center justify-center gap-2 px-4 py-6 border border-dashed rounded-xl cursor-pointer transition-colors"
      :class="
        isDragOver
          ? 'border-n-brand bg-n-alpha-2'
          : 'border-n-weak hover:border-n-brand'
      "
      @dragover.prevent="isDragOver = true"
      @dragleave.prevent="isDragOver = false"
      @drop.prevent="onDrop"
    >
      <input
        ref="fileInput"
        type="file"
        class="hidden"
        accept=".mp3,.wav,.ogg,audio/mpeg,audio/wav,audio/ogg"
        :disabled="isUploading"
        @change="onFileChange"
      />
      <Icon icon="i-lucide-upload" class="size-4 text-n-slate-11" />
      <span class="text-sm text-n-slate-12">
        {{
          isUploading
            ? $t(`${i18nKeyPrefix}.SOUNDS.UPLOADING`)
            : $t(`${i18nKeyPrefix}.SOUNDS.CHOOSE_FILE`)
        }}
      </span>
    </label>

    <div
      v-for="sound in uploadedSounds"
      :key="sound.id"
      class="flex items-center gap-3 p-3 border border-n-weak rounded-xl"
    >
      <div class="flex-1 min-w-0">
        <p class="text-sm font-medium truncate text-n-slate-12">
          {{ sound.filename }}
        </p>
        <p class="text-xs text-n-slate-11">
          {{
            $t(`${i18nKeyPrefix}.SOUNDS.UPLOADED`, {
              size: formatFileSize(sound.byte_size),
            })
          }}
        </p>
      </div>
      <ButtonV4
        size="sm"
        variant="ghost"
        color="slate"
        icon="i-lucide-volume-2"
        :title="$t(`${i18nKeyPrefix}.PLAY`)"
        @click="playSound(sound)"
      />
      <ButtonV4
        size="sm"
        variant="ghost"
        color="ruby"
        icon="i-lucide-trash-2"
        :title="$t(`${i18nKeyPrefix}.SOUNDS.DELETE`)"
        @click="deleteSound(sound)"
      />
    </div>
  </div>
</template>
