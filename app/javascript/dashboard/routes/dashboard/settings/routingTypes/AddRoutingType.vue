<script setup>
import { ref, computed, onMounted } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required } from '@vuelidate/validators';

import NextButton from 'dashboard/components-next/button/Button.vue';
import RoutingTypeAttributeValueInput from './RoutingTypeAttributeValueInput.vue';

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const name = ref('');
const attributeKey = ref('');
const attributeValue = ref('');

const rules = {
  name: { required },
  attributeKey: { required },
  attributeValue: { required },
};
const v$ = useVuelidate(rules, { name, attributeKey, attributeValue });

const uiFlags = computed(() => store.getters['routingTypes/getUIFlags']);
const attributes = computed(() => store.getters['attributes/getAttributes']);
const contactAttributes = computed(() =>
  attributes.value.filter(a => a.attribute_model === 'contact_attribute')
);

onMounted(() => {
  store.dispatch('attributes/get');
});

const formatStepNumber = step => String(step).padStart(2, '0');

const onClose = () => {
  emit('close');
};

const onSubmit = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  try {
    await store.dispatch('routingTypes/create', {
      name: name.value,
      attribute_key: attributeKey.value,
      attribute_value: attributeValue.value,
    });
    useAlert(t('ROUTING_TYPES.ADD.API.SUCCESS_MESSAGE'));
    onClose();
  } catch (error) {
    useAlert(t('ROUTING_TYPES.ADD.API.ERROR_MESSAGE'));
  }
};
</script>

<template>
  <div class="flex flex-col gap-0">
    <div class="px-8 pt-8 pb-6 border-b border-white/10">
      <p
        class="text-xs font-semibold tracking-[0.2em] text-[#4ade80] uppercase mb-1"
      >
        {{ $t('ROUTING_TYPES.HEADER') }}
      </p>
      <h2 class="text-3xl font-black tracking-wide text-white uppercase">
        {{ $t('ROUTING_TYPES.ADD.TITLE') }}
      </h2>
    </div>

    <form class="flex flex-col gap-6 px-8 py-6" @submit.prevent="onSubmit">
      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2">
          <span class="text-xs font-bold text-[#4ade80] tracking-widest">{{
            formatStepNumber(1)
          }}</span>
          <span
            class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase"
            >{{ $t('ROUTING_TYPES.FORM.NAME.LABEL') }}</span
          >
        </div>
        <div
          class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
          :class="{ 'border-red-500/50': v$.name.$error }"
        >
          <span
            class="text-[10px] font-semibold tracking-[0.15em] text-[#4ade80] uppercase"
            >{{ $t('ROUTING_TYPES.FORM.NAME.LABEL') }}</span
          >
          <input
            v-model="name"
            type="text"
            :placeholder="$t('ROUTING_TYPES.FORM.NAME.PLACEHOLDER')"
            class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0"
            data-testid="routing-type-name"
            @blur="v$.name.$touch"
          />
        </div>
      </div>

      <div class="border-t border-white/10" />

      <div class="flex flex-col gap-3">
        <div class="flex items-center gap-2">
          <span class="text-xs font-bold text-[#4ade80] tracking-widest">{{
            formatStepNumber(2)
          }}</span>
          <span
            class="text-xs font-semibold tracking-[0.18em] text-n-slate-10 uppercase"
            >{{ $t('ROUTING_TYPES.FORM.ATTRIBUTE_KEY.LABEL') }}</span
          >
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div
            class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
            :class="{ 'border-red-500/50': v$.attributeKey.$error }"
          >
            <span
              class="text-[10px] font-semibold tracking-[0.15em] text-[#4ade80] uppercase"
              >{{ $t('ROUTING_TYPES.FORM.ATTRIBUTE_KEY.LABEL') }}</span
            >
            <select
              v-model="attributeKey"
              class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 p-0"
              @blur="v$.attributeKey.$touch"
            >
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
          </div>

          <div
            class="flex flex-col gap-1 rounded-xl border border-white/10 bg-white/5 px-4 pt-1.5 pb-2 transition-all duration-200 hover:border-[rgba(74,222,128,0.4)] hover:shadow-[0_0_12px_rgba(74,222,128,0.15)] focus-within:border-[rgba(74,222,128,0.5)] focus-within:shadow-[0_0_16px_rgba(74,222,128,0.2)]"
            :class="{ 'border-red-500/50': v$.attributeValue.$error }"
          >
            <span
              class="text-[10px] font-semibold tracking-[0.15em] text-n-slate-10 uppercase"
              >{{ $t('ROUTING_TYPES.FORM.ATTRIBUTE_VALUE.LABEL') }}</span
            >
            <RoutingTypeAttributeValueInput
              v-model="attributeValue"
              :attribute-key="attributeKey"
              :contact-attributes="contactAttributes"
              @blur="v$.attributeValue.$touch"
            />
          </div>
        </div>
      </div>

      <div class="border-t border-white/10" />

      <div class="flex items-center justify-between gap-3 py-2">
        <NextButton
          variant="link"
          type="reset"
          :label="$t('ROUTING_TYPES.ADD.CANCEL_BUTTON_TEXT')"
          class="h-10 hover:!no-underline hover:text-n-brand"
          @click.prevent="onClose"
        />
        <NextButton
          type="submit"
          data-testid="routing-type-submit"
          color="teal"
          :label="$t('ROUTING_TYPES.ADD.FORM.SUBMIT')"
          :disabled="v$.$invalid || uiFlags.isCreating"
          :is-loading="uiFlags.isCreating"
        />
      </div>
    </form>
  </div>
</template>
