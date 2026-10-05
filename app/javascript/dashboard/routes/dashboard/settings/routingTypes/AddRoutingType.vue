<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';

import RoutingTypeForm from './RoutingTypeForm.vue';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const uiFlags = computed(() => store.getters['routingTypes/getUIFlags']);

const onClose = () => {
  emit('close');
};

const onSubmit = async payload => {
  try {
    await store.dispatch('routingTypes/create', payload);
    useAlert(t('ROUTING_TYPES.ADD.API.SUCCESS_MESSAGE'));
    onClose();
  } catch (error) {
    useAlert(t('ROUTING_TYPES.ADD.API.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="$t('ROUTING_TYPES.ADD.TITLE')"
      :header-content="$t('ROUTING_TYPES.ADD.DESC')"
    />
    <RoutingTypeForm
      :submit-label="$t('ROUTING_TYPES.ADD.FORM.SUBMIT')"
      :is-submitting="uiFlags.isCreating"
      @close="onClose"
      @submit="onSubmit"
    />
  </div>
</template>
