<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useStore, useStoreGetters } from 'dashboard/composables/store';
import forceTransferApi from 'dashboard/api/forceTransfer';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const getters = useStoreGetters();
const { t } = useI18n();
const isLoading = ref(false);

const currentChat = computed(() => getters.getSelectedChat.value);

const transfer = async () => {
  isLoading.value = true;

  try {
    await forceTransferApi.transfer(currentChat.value.id);
    useAlert(t('FORCE_TRANSFER.SUCCESS'));
    store.dispatch('getConversation', currentChat.value.id);
  } catch {
    useAlert(t('FORCE_TRANSFER.ERROR'));
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <Button
    :label="t('FORCE_TRANSFER.ACTION')"
    size="sm"
    color="slate"
    no-animation
    class="me-2"
    :is-loading="isLoading"
    @click="transfer"
  />
</template>
