<script setup>
import SettingsToggleSection from 'dashboard/components-next/Settings/SettingsToggleSection.vue';
import Input from 'dashboard/components-next/input/Input.vue';

defineProps({
  showLikeDislikeHint: {
    type: Boolean,
    default: false,
  },
});

const messageEnabled = defineModel('messageEnabled', {
  type: Boolean,
  default: true,
});
const csatOnResolveEnabled = defineModel('csatOnResolveEnabled', {
  type: Boolean,
  default: true,
});
const likeDislikeHintEnabled = defineModel('likeDislikeHintEnabled', {
  type: Boolean,
  default: true,
});
const likeDislikeHintMessage = defineModel('likeDislikeHintMessage', {
  type: String,
  default: '',
});
</script>

<template>
  <SettingsToggleSection
    v-if="showLikeDislikeHint"
    v-model="likeDislikeHintEnabled"
    :header="$t('INBOX_MGMT.CSAT.LIKE_DISLIKE_HINT.TOGGLE_LABEL')"
    :description="$t('INBOX_MGMT.CSAT.LIKE_DISLIKE_HINT.TOGGLE_DESCRIPTION')"
  >
    <template v-if="likeDislikeHintEnabled" #editor>
      <Input
        v-model="likeDislikeHintMessage"
        :placeholder="$t('INBOX_MGMT.CSAT.LIKE_DISLIKE_HINT.PLACEHOLDER')"
        class="w-full"
      />
    </template>
  </SettingsToggleSection>
  <SettingsToggleSection
    v-model="csatOnResolveEnabled"
    :header="$t('INBOX_MGMT.CSAT.CSAT_ON_RESOLVE.TOGGLE_LABEL')"
    :description="$t('INBOX_MGMT.CSAT.CSAT_ON_RESOLVE.TOGGLE_DESCRIPTION')"
  />
  <SettingsToggleSection
    v-model="messageEnabled"
    :header="$t('INBOX_MGMT.CSAT.MESSAGE.TOGGLE_LABEL')"
    :description="$t('INBOX_MGMT.CSAT.MESSAGE.TOGGLE_DESCRIPTION')"
  />
</template>
