<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { OnClickOutside } from '@vueuse/components';
import { useAlert } from 'dashboard/composables';
import Button from 'dashboard/components-next/button/Button.vue';
import ReportFilterPresetsAPI from 'dashboard/api/reportFilterPresets';

const props = defineProps({
  filters: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['apply']);

const { t } = useI18n();
const presets = ref([]);
const isMenuOpen = ref(false);
const isSaveOpen = ref(false);
const presetName = ref('');
const renamingId = ref(null);
const renameValue = ref('');
const isSaving = ref(false);

const canSave = computed(() => presetName.value.trim().length > 0);

const errorMessage = error =>
  error?.response?.data?.message || error?.response?.data?.error;

const loadPresets = async () => {
  try {
    const { data } = await ReportFilterPresetsAPI.get();
    presets.value = data;
  } catch (error) {
    useAlert(errorMessage(error) || t('REPORT.FILTER_PRESETS.LOAD_FAILED'));
  }
};

const closePanels = () => {
  isMenuOpen.value = false;
  isSaveOpen.value = false;
  renamingId.value = null;
};

const toggleSave = () => {
  isMenuOpen.value = false;
  isSaveOpen.value = !isSaveOpen.value;
  if (isSaveOpen.value) presetName.value = '';
};

const toggleMenu = () => {
  isSaveOpen.value = false;
  isMenuOpen.value = !isMenuOpen.value;
  renamingId.value = null;
};

const savePreset = async () => {
  const name = presetName.value.trim();
  if (!name || isSaving.value) return;

  isSaving.value = true;
  try {
    const { data } = await ReportFilterPresetsAPI.create({
      report_filter_preset: {
        name,
        filters: props.filters,
      },
    });
    presets.value = [...presets.value, data].sort((left, right) =>
      left.name.localeCompare(right.name)
    );
    presetName.value = '';
    isSaveOpen.value = false;
    useAlert(t('REPORT.FILTER_PRESETS.SAVED'));
  } catch (error) {
    useAlert(errorMessage(error) || t('REPORT.FILTER_PRESETS.SAVE_FAILED'));
  } finally {
    isSaving.value = false;
  }
};

const applyPreset = preset => {
  emit('apply', preset.filters || {});
  isMenuOpen.value = false;
};

const startRename = preset => {
  renamingId.value = preset.id;
  renameValue.value = preset.name;
};

const confirmRename = async preset => {
  const name = renameValue.value.trim();
  if (!name || name === preset.name) {
    renamingId.value = null;
    return;
  }

  try {
    const { data } = await ReportFilterPresetsAPI.update(preset.id, {
      report_filter_preset: { name },
    });
    presets.value = presets.value
      .map(item => (item.id === preset.id ? data : item))
      .sort((left, right) => left.name.localeCompare(right.name));
    renamingId.value = null;
    useAlert(t('REPORT.FILTER_PRESETS.UPDATED'));
  } catch (error) {
    useAlert(errorMessage(error) || t('REPORT.FILTER_PRESETS.UPDATE_FAILED'));
  }
};

const deletePreset = async preset => {
  try {
    await ReportFilterPresetsAPI.delete(preset.id);
    presets.value = presets.value.filter(item => item.id !== preset.id);
    if (!presets.value.length) isMenuOpen.value = false;
    useAlert(t('REPORT.FILTER_PRESETS.DELETED'));
  } catch (error) {
    useAlert(errorMessage(error) || t('REPORT.FILTER_PRESETS.DELETE_FAILED'));
  }
};

onMounted(loadPresets);
</script>

<template>
  <OnClickOutside @trigger="closePanels">
    <div class="relative flex items-center justify-end gap-2">
      <Button
        type="button"
        :label="t('REPORT.FILTER_PRESETS.SAVE')"
        icon="i-lucide-save"
        variant="outline"
        color="slate"
        size="sm"
        @click="toggleSave"
      />
      <Button
        v-if="presets.length"
        type="button"
        :label="t('REPORT.FILTER_PRESETS.MY_PRESETS')"
        icon="i-lucide-bookmark"
        variant="faded"
        color="slate"
        size="sm"
        @click="toggleMenu"
      />

      <div
        v-if="isSaveOpen"
        class="absolute end-0 top-full z-30 mt-2 w-72 rounded-xl border border-n-weak bg-n-solid-1 p-3 shadow-lg"
      >
        <input
          v-model="presetName"
          type="text"
          maxlength="100"
          class="mb-2 w-full"
          :placeholder="t('REPORT.FILTER_PRESETS.NAME_PLACEHOLDER')"
          @keydown.enter="savePreset"
        />
        <Button
          type="button"
          :label="t('REPORT.FILTER_PRESETS.CONFIRM')"
          size="sm"
          :is-loading="isSaving"
          :disabled="!canSave"
          @click="savePreset"
        />
      </div>

      <div
        v-if="isMenuOpen"
        class="absolute end-0 top-full z-30 mt-2 w-80 rounded-xl border border-n-weak bg-n-solid-1 p-2 shadow-lg"
      >
        <p v-if="!presets.length" class="px-2 py-1.5 text-sm text-n-slate-11">
          {{ t('REPORT.FILTER_PRESETS.EMPTY') }}
        </p>
        <div
          v-for="preset in presets"
          :key="preset.id"
          class="flex items-center gap-1 rounded-lg px-1 py-1 hover:bg-n-alpha-2"
        >
          <template v-if="renamingId === preset.id">
            <input
              v-model="renameValue"
              type="text"
              maxlength="100"
              class="min-w-0 flex-1"
              @keydown.enter="confirmRename(preset)"
              @keydown.esc="renamingId = null"
            />
            <button
              type="button"
              class="rounded-md px-2 py-1 text-xs text-n-slate-12"
              @click="confirmRename(preset)"
            >
              {{ t('REPORT.FILTER_PRESETS.CONFIRM') }}
            </button>
          </template>
          <template v-else>
            <button
              type="button"
              class="min-w-0 flex-1 truncate px-2 py-1 text-start text-sm text-n-slate-12"
              @click="applyPreset(preset)"
            >
              {{ preset.name }}
            </button>
            <button
              type="button"
              class="inline-flex size-7 items-center justify-center rounded-md text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
              :aria-label="t('REPORT.FILTER_PRESETS.RENAME')"
              @click="startRename(preset)"
            >
              <span class="i-lucide-pencil size-3.5" />
            </button>
            <button
              type="button"
              class="inline-flex size-7 items-center justify-center rounded-md text-n-slate-11 hover:bg-n-ruby-3 hover:text-n-ruby-11"
              :aria-label="t('REPORT.FILTER_PRESETS.DELETE')"
              @click="deletePreset(preset)"
            >
              <span class="i-lucide-trash-2 size-3.5" />
            </button>
          </template>
        </div>
      </div>
    </div>
  </OnClickOutside>
</template>
