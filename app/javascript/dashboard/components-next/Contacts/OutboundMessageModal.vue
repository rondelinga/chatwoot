<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import ContactAPI from 'dashboard/api/contacts';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const props = defineProps({
  contact: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const router = useRouter();
const currentAccountId = useMapGetter('getCurrentAccountId');

const dialogRef = ref(null);
const inboxId = ref('');
const content = ref('');
const inboxes = ref([]);
const isLoadingInboxes = ref(false);
const isSending = ref(false);

const contactName = computed(() => props.contact.name || '');
const contactEmail = computed(() => props.contact.email || '');
const contactLabel = computed(() => {
  if (contactEmail.value) {
    return `${contactName.value} (${contactEmail.value})`;
  }
  return contactName.value;
});

const channelTypeOf = inbox => inbox.channel_type || inbox.channelType;

const channelLabel = inbox => {
  const channelType = channelTypeOf(inbox);
  if (channelType === INBOX_TYPES.TELEGRAM) {
    return t('CONTACT_PANEL.OUTBOUND_MESSAGE.CHANNEL.TELEGRAM');
  }
  if (channelType === INBOX_TYPES.WEB) {
    return t('CONTACT_PANEL.OUTBOUND_MESSAGE.CHANNEL.WEB_WIDGET');
  }
  return inbox.name;
};

const inboxOptions = computed(() =>
  inboxes.value.map(item => ({
    value: String(item.inbox.id),
    label: `${item.inbox.name} · ${channelLabel(item.inbox)}`,
  }))
);

const selectedInbox = computed(() =>
  inboxes.value.find(item => String(item.inbox.id) === String(inboxId.value))
);

const deliveryHint = computed(() => {
  const channelType = channelTypeOf(selectedInbox.value?.inbox || {});
  if (channelType === INBOX_TYPES.TELEGRAM) {
    return t('CONTACT_PANEL.OUTBOUND_MESSAGE.TELEGRAM_HINT');
  }
  if (channelType === INBOX_TYPES.WEB) {
    return t('CONTACT_PANEL.OUTBOUND_MESSAGE.PUSH_HINT');
  }
  return t('CONTACT_PANEL.OUTBOUND_MESSAGE.HINT');
});

const isMessageBlank = computed(() => !content.value.trim());
const canSubmit = computed(
  () => Boolean(inboxId.value) && !isMessageBlank.value && !isSending.value
);

const loadInboxes = async () => {
  if (!props.contact.id) return;
  isLoadingInboxes.value = true;
  try {
    const { data } = await ContactAPI.getOutboundInboxes(props.contact.id);
    inboxes.value = data.payload || [];
    if (inboxes.value.length === 1) {
      inboxId.value = String(inboxes.value[0].inbox.id);
    }
  } catch {
    inboxes.value = [];
  } finally {
    isLoadingInboxes.value = false;
  }
};

const resetForm = () => {
  inboxId.value = '';
  content.value = '';
  inboxes.value = [];
};

const open = async () => {
  resetForm();
  dialogRef.value?.open();
  await loadInboxes();
};

const handleDialogClose = () => {
  resetForm();
  emit('close');
};

const sendMessage = async () => {
  if (!canSubmit.value) return;

  isSending.value = true;
  try {
    const { data } = await ContactAPI.sendOutboundMessage(props.contact.id, {
      inboxId: inboxId.value,
      content: content.value.trim(),
    });
    dialogRef.value?.close();
    router.push({
      name: 'inbox_conversation',
      params: {
        accountId: currentAccountId.value,
        conversation_id: data.id,
      },
    });
  } catch (error) {
    useAlert(
      error.response?.data?.error || t('CONTACT_PANEL.OUTBOUND_MESSAGE.ERROR')
    );
  } finally {
    isSending.value = false;
  }
};

watch(
  () => props.contact.id,
  () => {
    resetForm();
  }
);

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    width="lg"
    :title="t('CONTACT_PANEL.OUTBOUND_MESSAGE.TITLE')"
    :cancel-button-label="t('CONTACT_PANEL.OUTBOUND_MESSAGE.CANCEL')"
    :confirm-button-label="t('CONTACT_PANEL.OUTBOUND_MESSAGE.SEND')"
    :disable-confirm-button="!canSubmit"
    :is-loading="isSending"
    overflow-y-auto
    @confirm="sendMessage"
    @close="handleDialogClose"
  >
    <div class="flex flex-col gap-4">
      <div class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CONTACT_PANEL.OUTBOUND_MESSAGE.CONTACT_LABEL') }}
        </span>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ contactLabel }}
        </p>
      </div>

      <div class="flex flex-col gap-1">
        <span class="text-sm font-medium text-n-slate-12">
          {{ t('CONTACT_PANEL.OUTBOUND_MESSAGE.INBOX_LABEL') }}
        </span>
        <Select
          v-model="inboxId"
          :options="inboxOptions"
          :placeholder="t('CONTACT_PANEL.OUTBOUND_MESSAGE.INBOX_PLACEHOLDER')"
          :disabled="isLoadingInboxes || !inboxOptions.length"
        />
      </div>

      <TextArea
        v-model="content"
        :label="t('CONTACT_PANEL.OUTBOUND_MESSAGE.MESSAGE_LABEL')"
        :placeholder="t('CONTACT_PANEL.OUTBOUND_MESSAGE.MESSAGE_PLACEHOLDER')"
        :max-length="10000"
        :show-character-count="false"
        auto-height
        min-height="8rem"
        :message="
          isMessageBlank && content.length
            ? t('CONTACT_PANEL.OUTBOUND_MESSAGE.MESSAGE_ERROR')
            : ''
        "
        :message-type="isMessageBlank && content.length ? 'error' : 'info'"
      />

      <p class="mb-0 text-sm text-n-amber-11">
        {{ deliveryHint }}
      </p>
    </div>
  </Dialog>
</template>
