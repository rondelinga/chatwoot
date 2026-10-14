<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import FilterButton from 'dashboard/components/ui/Dropdown/DropdownButton.vue';
import FilterListDropdown from 'dashboard/components/ui/Dropdown/DropdownList.vue';

const props = defineProps({
  since: {
    type: String,
    required: true,
  },
  until: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['change']);

const { t } = useI18n();

const showMenu = ref(false);

const buttonText = computed(
  () =>
    `${props.since} ${t('AGENT_ACTIVITY_REPORTS.FILTERS.TIME_RANGE_SEPARATOR')} ${props.until} ${t('AGENT_ACTIVITY_REPORTS.FILTERS.TIME_ZONE_UTC')}`
);

const toggleMenu = () => {
  showMenu.value = !showMenu.value;
};

const closeMenu = () => {
  showMenu.value = false;
};

const updateTime = (key, value) => {
  if (!value) return;
  emit('change', { since: props.since, until: props.until, [key]: value });
};
</script>

<template>
  <div v-on-clickaway="closeMenu" class="relative">
    <FilterButton
      trailing-icon
      icon="i-lucide-chevron-down"
      :button-text="buttonText"
      @click="toggleMenu"
    />
    <FilterListDropdown
      v-if="showMenu"
      class="flex flex-col gap-3 p-3 w-56 top-10 start-0"
    >
      <template #listItem>
        <label class="flex items-center justify-between gap-2 text-sm">
          <span class="text-n-slate-11">
            {{ t('REPORT.FILTERS.TIME_RANGE.SINCE') }}
          </span>
          <input
            :value="since"
            type="time"
            class="!mb-0 !w-32"
            @change="updateTime('since', $event.target.value)"
          />
        </label>
        <label class="flex items-center justify-between gap-2 text-sm">
          <span class="text-n-slate-11">
            {{ t('REPORT.FILTERS.TIME_RANGE.UNTIL') }}
          </span>
          <input
            :value="until"
            type="time"
            class="!mb-0 !w-32"
            @change="updateTime('until', $event.target.value)"
          />
        </label>
      </template>
    </FilterListDropdown>
  </div>
</template>
