<script setup>
import { computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const props = defineProps({
  attributeKey: {
    type: String,
    required: true,
  },
  contactAttributes: {
    type: Array,
    required: true,
  },
});

const emit = defineEmits(['blur']);

const modelValue = defineModel({
  type: String,
  required: true,
});

const { t } = useI18n();

const selectedAttribute = computed(() =>
  props.contactAttributes.find(
    attribute => attribute.attribute_key === props.attributeKey
  )
);

const displayType = computed(
  () => selectedAttribute.value?.attribute_display_type ?? 'text'
);

const listOptions = computed(
  () => selectedAttribute.value?.attribute_values ?? []
);

const booleanValue = computed({
  get: () => modelValue.value === 'true',
  set: value => {
    modelValue.value = value ? 'true' : 'false';
  },
});

const inputType = computed(() => {
  if (displayType.value === 'number') return 'number';
  if (displayType.value === 'date') return 'date';
  return 'text';
});

const resetValueForAttribute = () => {
  if (displayType.value === 'checkbox') {
    modelValue.value = 'false';
  } else if (displayType.value === 'list') {
    modelValue.value = listOptions.value[0] ?? '';
  } else {
    modelValue.value = '';
  }
};

watch(
  () => props.attributeKey,
  (newKey, oldKey) => {
    if (newKey === oldKey) return;

    if (!newKey) {
      modelValue.value = '';
      return;
    }

    resetValueForAttribute();
  }
);
</script>

<template>
  <div v-if="displayType === 'checkbox'" class="flex items-center h-6">
    <Switch v-model="booleanValue" @change="emit('blur')" />
    <span class="ml-2 text-sm text-n-slate-9">
      {{
        booleanValue
          ? t('FILTER.ATTRIBUTE_LABELS.TRUE')
          : t('FILTER.ATTRIBUTE_LABELS.FALSE')
      }}
    </span>
  </div>

  <select
    v-else-if="displayType === 'list'"
    v-model="modelValue"
    class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 p-0 w-full"
    @blur="emit('blur')"
  >
    <option v-if="!listOptions.length" value="" disabled>
      {{ $t('ROUTING_TYPES.FORM.ATTRIBUTE_VALUE.PLACEHOLDER') }}
    </option>
    <option v-for="option in listOptions" :key="option" :value="option">
      {{ option }}
    </option>
  </select>

  <input
    v-else
    v-model="modelValue"
    :type="inputType"
    :placeholder="$t('ROUTING_TYPES.FORM.ATTRIBUTE_VALUE.PLACEHOLDER')"
    class="h-6 bg-transparent border-0 outline-none text-sm text-n-slate-9 placeholder:text-n-slate-8 p-0 w-full"
    data-testid="routing-type-value"
    @blur="emit('blur')"
  />
</template>
