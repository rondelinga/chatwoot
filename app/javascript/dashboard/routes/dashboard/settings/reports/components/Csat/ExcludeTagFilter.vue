<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import { useStore } from 'vuex';
import ComboBoxDropdown from 'dashboard/components-next/combobox/ComboBoxDropdown.vue';

const props = defineProps({
  selected: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update']);

const { t } = useI18n();
const store = useStore();
const isOpen = ref(false);
const search = ref('');

const labels = computed(() => store.getters['labels/getLabels'] || []);
const options = computed(() => {
  const query = search.value.trim().toLowerCase();

  return labels.value
    .filter(label => !query || label.title.toLowerCase().includes(query))
    .map(label => ({ value: label.title, label: label.title }));
});

const toggle = option => {
  const next = props.selected.includes(option.value)
    ? props.selected.filter(title => title !== option.value)
    : [...props.selected, option.value];
  emit('update', next);
};

const remove = title => {
  emit(
    'update',
    props.selected.filter(item => item !== title)
  );
};

onMounted(() => {
  store.dispatch('labels/get');
});
</script>

<template>
  <div class="flex flex-wrap items-center gap-2">
    <OnClickOutside @trigger="isOpen = false">
      <div class="relative w-72">
        <button
          type="button"
          class="inline-flex items-center h-8 gap-2 px-3 text-sm rounded-lg bg-n-alpha-2 text-n-slate-12"
          @click="isOpen = !isOpen"
        >
          <span class="i-lucide-tag size-4" />
          {{ t('CSAT_REPORTS.EXCLUSIONS.LABEL') }}
        </button>
        <ComboBoxDropdown
          v-model:search-value="search"
          :open="isOpen"
          :options="options"
          :search-placeholder="t('CSAT_REPORTS.EXCLUSIONS.SEARCH')"
          :empty-state="t('CSAT_REPORTS.EXCLUSIONS.EMPTY')"
          multiple
          :selected-values="selected"
          @select="toggle"
        />
      </div>
    </OnClickOutside>

    <button
      v-for="title in selected"
      :key="title"
      type="button"
      class="inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-full bg-n-ruby-3 text-n-ruby-11"
      @click="remove(title)"
    >
      <span>{{ title }}</span>
      <span class="i-lucide-x size-3.5" />
    </button>

    <button
      v-if="selected.length"
      type="button"
      class="inline-flex items-center h-8 px-3 text-sm rounded-lg text-n-ruby-11 hover:bg-n-ruby-2"
      @click="emit('update', [])"
    >
      {{ t('CSAT_REPORTS.EXCLUSIONS.CLEAR') }}
    </button>
  </div>
</template>
