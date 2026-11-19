<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import {
  getUserPermissions,
  hasPermissions,
} from 'dashboard/helper/permissionsHelper';
import { CONVERSATION_OUTBOUND_PERMISSIONS } from 'dashboard/constants/permissions.js';
import ContactAPI from 'dashboard/api/contacts';

import Button from 'dashboard/components-next/button/Button.vue';
import OutboundMessageModal from './OutboundMessageModal.vue';

const props = defineProps({
  contact: {
    type: Object,
    default: () => ({}),
  },
  label: {
    type: String,
    default: '',
  },
  size: {
    type: String,
    default: 'sm',
  },
  iconOnly: {
    type: Boolean,
    default: false,
  },
  slate: {
    type: Boolean,
    default: false,
  },
  faded: {
    type: Boolean,
    default: false,
  },
});

const { t } = useI18n();
const currentUser = useMapGetter('getCurrentUser');
const currentAccountId = useMapGetter('getCurrentAccountId');

const modalRef = ref(null);
const hasOutboundSession = ref(false);
const isFetching = ref(false);

const currentPermissions = computed(() =>
  getUserPermissions(currentUser.value, currentAccountId.value)
);

const canSendOutbound = computed(() => {
  if (
    hasPermissions(
      ['administrator', CONVERSATION_OUTBOUND_PERMISSIONS],
      currentPermissions.value
    )
  ) {
    return true;
  }

  return (
    hasPermissions(['agent'], currentPermissions.value) &&
    !hasPermissions(['custom_role'], currentPermissions.value)
  );
});

const isDisabled = computed(
  () => isFetching.value || !hasOutboundSession.value || !props.contact?.id
);

const buttonLabel = computed(() => {
  if (props.iconOnly) return '';
  return props.label || t('CONTACT_PANEL.OUTBOUND_MESSAGE.BUTTON');
});

const tooltipLabel = computed(() => {
  if (!hasOutboundSession.value) {
    return t('CONTACT_PANEL.OUTBOUND_MESSAGE.NO_SESSION');
  }
  return t('CONTACT_PANEL.OUTBOUND_MESSAGE.BUTTON');
});

const fetchOutboundSession = async () => {
  if (!canSendOutbound.value || !props.contact?.id) {
    hasOutboundSession.value = false;
    return;
  }

  isFetching.value = true;
  try {
    const { data } = await ContactAPI.getOutboundInboxes(props.contact.id);
    hasOutboundSession.value = Boolean(data.payload?.length);
  } catch {
    hasOutboundSession.value = false;
  } finally {
    isFetching.value = false;
  }
};

const openModal = () => {
  if (isDisabled.value) return;
  modalRef.value?.open();
};

watch(
  () => props.contact?.id,
  () => {
    fetchOutboundSession();
  },
  { immediate: true }
);
</script>

<template>
  <Button
    v-if="canSendOutbound"
    v-tooltip.top-end="tooltipLabel"
    :label="buttonLabel"
    icon="i-lucide-send"
    :size="size"
    :slate="slate"
    :faded="faded"
    :disabled="isDisabled"
    @click="openModal"
  />
  <OutboundMessageModal
    v-if="canSendOutbound"
    ref="modalRef"
    :contact="contact"
  />
</template>
