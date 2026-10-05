<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useStore } from 'vuex';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';

import NextButton from 'dashboard/components-next/button/Button.vue';
import RoutingTypeAttributeValueInput from './RoutingTypeAttributeValueInput.vue';

const props = defineProps({
  initialRoutingType: {
    type: Object,
    default: null,
  },
  submitLabel: {
    type: String,
    required: true,
  },
  isSubmitting: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['close', 'submit']);

const store = useStore();

const name = ref('');
const attributeKey = ref('');
const attributeValue = ref('');

const rules = {
  name: { required },
  attributeKey: { required },
  attributeValue: { required },
};
const v$ = useVuelidate(rules, { name, attributeKey, attributeValue });

const attributes = computed(() => store.getters['attributes/getAttributes']);
const contactAttributes = computed(() =>
  attributes.value.filter(a => a.attribute_model === 'contact_attribute')
);

const applyInitialValues = routingType => {
  if (!routingType) {
    name.value = '';
    attributeKey.value = '';
    attributeValue.value = '';
    return;
  }

  name.value = routingType.name ?? '';
  attributeKey.value = routingType.attribute_key ?? '';
  attributeValue.value = routingType.attribute_value ?? '';
};

onMounted(() => {
  store.dispatch('attributes/get');
  applyInitialValues(props.initialRoutingType);
});

watch(
  () => props.initialRoutingType,
  routingType => {
    applyInitialValues(routingType);
    v$.value.$reset();
  }
);

const onClose = () => {
  emit('close');
};

const onSubmit = () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  emit('submit', {
    name: name.value,
    attribute_key: attributeKey.value,
    attribute_value: attributeValue.value,
  });
};
</script>

<template>
  <form class="flex flex-wrap mx-0" @submit.prevent="onSubmit">
    <woot-input
      v-model="name"
      :class="{ error: v$.name.$error }"
      class="w-full"
      :label="$t('ROUTING_TYPES.FORM.NAME.LABEL')"
      :placeholder="$t('ROUTING_TYPES.FORM.NAME.PLACEHOLDER')"
      data-testid="routing-type-name"
      @blur="v$.name.$touch"
    />

    <label :class="{ error: v$.attributeKey.$error }" class="w-full">
      {{ $t('ROUTING_TYPES.FORM.ATTRIBUTE_KEY.LABEL') }}
      <select v-model="attributeKey" @blur="v$.attributeKey.$touch">
        <option value="" disabled>
          {{ $t('ROUTING_TYPES.FORM.ATTRIBUTE_KEY.PLACEHOLDER') }}
        </option>
        <option
          v-for="attr in contactAttributes"
          :key="attr.attribute_key"
          :value="attr.attribute_key"
        >
          {{ attr.attribute_display_name }}
        </option>
      </select>
    </label>

    <label :class="{ error: v$.attributeValue.$error }" class="w-full">
      {{ $t('ROUTING_TYPES.FORM.ATTRIBUTE_VALUE.LABEL') }}
      <RoutingTypeAttributeValueInput
        v-model="attributeValue"
        :attribute-key="attributeKey"
        :contact-attributes="contactAttributes"
        @blur="v$.attributeValue.$touch"
      />
    </label>

    <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
      <NextButton
        faded
        slate
        type="reset"
        :label="$t('ROUTING_TYPES.FORM.CANCEL')"
        @click.prevent="onClose"
      />
      <NextButton
        type="submit"
        data-testid="routing-type-submit"
        :label="submitLabel"
        :disabled="v$.$invalid || isSubmitting"
        :is-loading="isSubmitting"
      />
    </div>
  </form>
</template>
