<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';

const props = defineProps({
  inboxes: {
    type: Array,
    default: () => [],
  },
  unavailableIds: {
    type: Array,
    default: () => [],
  },
  setNumber: {
    type: Number,
    default: 1,
  },
});

const emit = defineEmits(['apply']);

const { t } = useI18n();

const dialogRef = ref(null);
const draftIds = ref([]);
const search = ref('');
const tab = ref('all');

const groupName = inbox => {
  const parts = inbox.name.trim().split(/\s+/);
  return parts.length > 1 ? parts[parts.length - 1] : '';
};

const groups = computed(() => {
  const names = props.inboxes.map(groupName).filter(Boolean);
  return [...new Set(names)].sort((left, right) => left.localeCompare(right));
});

const tabs = computed(() => [
  {
    id: 'all',
    label: `${t('INBOX_TEAM_ASSIGNMENT.ALL')} ${props.inboxes.length}`,
  },
  ...groups.value.map(name => ({
    id: name,
    label: `${name} ${props.inboxes.filter(inbox => groupName(inbox) === name).length}`,
  })),
]);

const visibleInboxes = computed(() => {
  const query = search.value.trim().toLowerCase();
  return props.inboxes.filter(inbox => {
    const matchesTab = tab.value === 'all' || groupName(inbox) === tab.value;
    const matchesQuery = !query || inbox.name.toLowerCase().includes(query);
    return matchesTab && matchesQuery;
  });
});

const selectableVisible = computed(() =>
  visibleInboxes.value.filter(inbox => !props.unavailableIds.includes(inbox.id))
);

const allVisibleSelected = computed(
  () =>
    selectableVisible.value.length > 0 &&
    selectableVisible.value.every(inbox => draftIds.value.includes(inbox.id))
);

const toggleInbox = inboxId => {
  if (props.unavailableIds.includes(inboxId)) return;

  if (draftIds.value.includes(inboxId)) {
    draftIds.value = draftIds.value.filter(id => id !== inboxId);
    return;
  }

  draftIds.value = [...draftIds.value, inboxId];
};

const toggleAllVisible = () => {
  const visibleIds = selectableVisible.value.map(inbox => inbox.id);
  if (allVisibleSelected.value) {
    draftIds.value = draftIds.value.filter(id => !visibleIds.includes(id));
    return;
  }

  draftIds.value = [...new Set([...draftIds.value, ...visibleIds])];
};

const open = selectedIds => {
  draftIds.value = [...selectedIds];
  search.value = '';
  tab.value = 'all';
  dialogRef.value?.open();
};

const apply = () => {
  emit('apply', draftIds.value);
  dialogRef.value?.close();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="xl"
    :title="$t('INBOX_TEAM_ASSIGNMENT.PICKER_TITLE', { n: setNumber })"
    :description="$t('INBOX_TEAM_ASSIGNMENT.PICKER_DESCRIPTION')"
    :confirm-button-label="$t('INBOX_TEAM_ASSIGNMENT.DONE')"
    overflow-y-auto
    @confirm="apply"
  >
    <label class="flex flex-col gap-1.5 text-sm text-n-slate-11">
      {{ $t('INBOX_TEAM_ASSIGNMENT.SEARCH') }}
      <input
        v-model="search"
        type="search"
        class="h-10 rounded-lg border border-n-weak bg-n-alpha-black2 px-3 text-sm text-n-slate-12"
        :placeholder="$t('INBOX_TEAM_ASSIGNMENT.SEARCH_PLACEHOLDER')"
      />
    </label>

    <div class="flex flex-wrap gap-2">
      <button
        v-for="item in tabs"
        :key="item.id"
        type="button"
        class="h-8 rounded-full border px-3 text-sm font-medium"
        :class="
          tab === item.id
            ? 'border-n-brand bg-n-brand text-white'
            : 'border-n-weak bg-n-background text-n-slate-12'
        "
        @click="tab = item.id"
      >
        {{ item.label }}
      </button>
    </div>

    <div class="overflow-hidden rounded-lg border border-n-weak">
      <label
        class="flex h-11 items-center gap-3 border-b border-n-weak bg-n-alpha-1 px-3 text-sm font-medium"
      >
        <Checkbox
          :model-value="allVisibleSelected"
          @update:model-value="toggleAllVisible"
        />
        {{
          $t('INBOX_TEAM_ASSIGNMENT.SELECT_ALL', {
            n: selectableVisible.length,
          })
        }}
      </label>
      <p
        v-if="!visibleInboxes.length"
        class="px-3 py-6 text-sm text-n-slate-11"
      >
        {{ $t('INBOX_TEAM_ASSIGNMENT.EMPTY_INBOXES') }}
      </p>
      <div v-else class="max-h-72 overflow-y-auto">
        <label
          v-for="inbox in visibleInboxes"
          :key="inbox.id"
          class="flex h-11 items-center gap-3 border-b border-n-weak px-3 text-sm last:border-b-0"
          :class="
            unavailableIds.includes(inbox.id) ? 'opacity-50' : 'cursor-pointer'
          "
        >
          <Checkbox
            :model-value="draftIds.includes(inbox.id)"
            :disabled="unavailableIds.includes(inbox.id)"
            @update:model-value="toggleInbox(inbox.id)"
          />
          <span class="min-w-0 flex-1 truncate text-n-slate-12">{{
            inbox.name
          }}</span>
          <span v-if="groupName(inbox)" class="text-xs text-n-slate-11">
            {{ groupName(inbox) }}
          </span>
        </label>
      </div>
    </div>

    <p class="mb-0 text-sm font-medium text-n-slate-12">
      {{
        $t('INBOX_TEAM_ASSIGNMENT.SELECTED', {
          selected: draftIds.length,
          total: inboxes.length,
        })
      }}
    </p>
  </Dialog>
</template>
