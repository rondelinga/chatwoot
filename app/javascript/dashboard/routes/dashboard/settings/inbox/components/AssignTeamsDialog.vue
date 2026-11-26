<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import InboxTeamAssignmentsAPI from 'dashboard/api/inboxTeamAssignments';
import AssignTeamsSourcePicker from './AssignTeamsSourcePicker.vue';

const props = defineProps({
  inboxes: {
    type: Array,
    default: () => [],
  },
});

const { t } = useI18n();
const store = useStore();
const teams = useMapGetter('teams/getTeams');

const dialogRef = ref(null);
const pickerRef = ref(null);
const isSaving = ref(false);
const mode = ref('add');
const activeSetKey = ref(null);
const sets = ref([]);

let nextKey = 1;

const emptySet = () => ({
  key: nextKey,
  inboxIds: [],
  teamIds: [],
  defaultTeamId: null,
});

const reset = () => {
  nextKey = 1;
  mode.value = 'add';
  activeSetKey.value = null;
  sets.value = [emptySet()];
  nextKey += 1;
};

const inboxName = inboxId =>
  props.inboxes.find(inbox => inbox.id === inboxId)?.name || '';

const visibleInboxIds = inboxIds => inboxIds.slice(0, 5);

const hiddenInboxCount = inboxIds => Math.max(inboxIds.length - 5, 0);

const validationMessage = computed(() => {
  const invalidIndex = sets.value.findIndex(
    set => !set.inboxIds.length || !set.teamIds.length || !set.defaultTeamId
  );
  if (invalidIndex === -1) return '';

  const set = sets.value[invalidIndex];
  const n = invalidIndex + 1;
  if (!set.inboxIds.length)
    return t('INBOX_TEAM_ASSIGNMENT.NEED_SOURCES', { n });
  if (!set.teamIds.length) return t('INBOX_TEAM_ASSIGNMENT.NEED_TEAMS', { n });
  return t('INBOX_TEAM_ASSIGNMENT.NEED_DEFAULT', { n });
});

const summary = computed(() => {
  const inboxCount = sets.value.reduce(
    (total, set) => total + set.inboxIds.length,
    0
  );
  const defaults = sets.value
    .map(set => teams.value.find(team => team.id === set.defaultTeamId)?.name)
    .filter(Boolean);

  return t('INBOX_TEAM_ASSIGNMENT.SUMMARY', {
    sets: sets.value.length,
    inboxes: inboxCount,
    defaults: defaults.join(', ') || '—',
  });
});

const activeSetNumber = computed(() => {
  const index = sets.value.findIndex(set => set.key === activeSetKey.value);
  return index === -1 ? 1 : index + 1;
});

const unavailableIds = computed(() =>
  sets.value
    .filter(set => set.key !== activeSetKey.value)
    .flatMap(set => set.inboxIds)
);

const addSet = () => {
  const set = emptySet();
  nextKey += 1;
  sets.value.push(set);
};

const removeSet = key => {
  sets.value = sets.value.filter(set => set.key !== key);
  if (!sets.value.length) addSet();
};

const toggleTeam = (set, teamId) => {
  if (set.teamIds.includes(teamId)) {
    set.teamIds = set.teamIds.filter(id => id !== teamId);
    if (set.defaultTeamId === teamId) {
      set.defaultTeamId = set.teamIds[0] || null;
    }
    return;
  }

  set.teamIds = [...set.teamIds, teamId];
  if (!set.defaultTeamId) set.defaultTeamId = teamId;
};

const markDefault = (set, teamId) => {
  if (!set.teamIds.includes(teamId)) {
    set.teamIds = [...set.teamIds, teamId];
  }
  set.defaultTeamId = teamId;
};

const openSources = set => {
  activeSetKey.value = set.key;
  pickerRef.value?.open(set.inboxIds);
};

const applySources = inboxIds => {
  const set = sets.value.find(item => item.key === activeSetKey.value);
  if (set) set.inboxIds = inboxIds;
};

const apply = async () => {
  if (validationMessage.value) return;

  isSaving.value = true;
  try {
    await InboxTeamAssignmentsAPI.create(
      sets.value.map(set => ({
        mode: mode.value,
        inbox_ids: set.inboxIds,
        team_configs: set.teamIds.map(teamId => ({
          team_id: teamId,
          is_default: teamId === set.defaultTeamId,
        })),
      }))
    );
    useAlert(t('INBOX_TEAM_ASSIGNMENT.SUCCESS'));
    dialogRef.value?.close();
  } catch (error) {
    useAlert(error?.response?.data?.error || t('INBOX_TEAM_ASSIGNMENT.ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const open = async () => {
  reset();
  await store.dispatch('teams/get');
  dialogRef.value?.open();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="4xl"
    :title="$t('INBOX_TEAM_ASSIGNMENT.TITLE')"
    :description="$t('INBOX_TEAM_ASSIGNMENT.DESCRIPTION')"
    :confirm-button-label="$t('INBOX_TEAM_ASSIGNMENT.APPLY')"
    :disable-confirm-button="Boolean(validationMessage)"
    :is-loading="isSaving"
    overflow-y-auto
    @confirm="apply"
  >
    <section
      v-for="(set, index) in sets"
      :key="set.key"
      class="flex flex-col gap-4 rounded-xl border border-n-weak p-4"
    >
      <div class="flex items-center justify-between gap-3">
        <h4 class="mb-0 text-sm font-medium text-n-slate-12">
          {{ $t('INBOX_TEAM_ASSIGNMENT.SET', { n: index + 1 }) }}
          ·
          {{
            $t('INBOX_TEAM_ASSIGNMENT.INBOX_COUNT', { n: set.inboxIds.length })
          }}
        </h4>
        <Button
          v-if="sets.length > 1"
          type="button"
          variant="ghost"
          color="slate"
          size="sm"
          :label="$t('INBOX_TEAM_ASSIGNMENT.REMOVE_SET')"
          @click="removeSet(set.key)"
        />
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <span
          v-for="inboxId in visibleInboxIds(set.inboxIds)"
          :key="inboxId"
          class="inline-flex h-7 items-center rounded-md border border-n-weak bg-n-alpha-1 px-2 text-sm text-n-slate-12"
        >
          {{ inboxName(inboxId) }}
        </span>
        <span
          v-if="hiddenInboxCount(set.inboxIds)"
          class="inline-flex h-7 items-center rounded-md border border-dashed border-n-slate-6 px-2 text-sm text-n-slate-11"
        >
          {{
            $t('INBOX_TEAM_ASSIGNMENT.MORE', {
              n: hiddenInboxCount(set.inboxIds),
            })
          }}
        </span>
        <Button
          type="button"
          variant="link"
          size="sm"
          :label="$t('INBOX_TEAM_ASSIGNMENT.CHOOSE_SOURCES')"
          @click="openSources(set)"
        />
      </div>

      <div class="flex flex-col gap-2">
        <p class="mb-0 text-xs text-n-slate-11">
          {{ $t('INBOX_TEAM_ASSIGNMENT.TEAMS_HINT') }}
        </p>
        <p v-if="!teams.length" class="mb-0 text-sm text-n-slate-11">
          {{ $t('INBOX_TEAM_ASSIGNMENT.EMPTY_TEAMS') }}
        </p>
        <div v-else class="grid grid-cols-1 gap-2 sm:grid-cols-2">
          <div
            v-for="team in teams"
            :key="team.id"
            class="flex items-center gap-2 rounded-lg border border-n-weak px-3 py-2"
          >
            <Checkbox
              :model-value="set.teamIds.includes(team.id)"
              @update:model-value="toggleTeam(set, team.id)"
            />
            <span class="min-w-0 flex-1 truncate text-sm text-n-slate-12">
              {{ team.name }}
            </span>
            <button
              type="button"
              class="grid size-7 place-items-center rounded-md"
              :class="
                set.defaultTeamId === team.id
                  ? 'bg-n-teal-3 text-n-teal-11'
                  : 'text-n-slate-8 hover:text-n-teal-11'
              "
              :aria-label="$t('INBOX_TEAM_ASSIGNMENT.DEFAULT')"
              :aria-pressed="set.defaultTeamId === team.id"
              @click="markDefault(set, team.id)"
            >
              <span class="i-lucide-check size-4" />
            </button>
          </div>
        </div>
      </div>
    </section>

    <Button
      type="button"
      variant="faded"
      color="slate"
      size="sm"
      icon="i-lucide-plus"
      :label="$t('INBOX_TEAM_ASSIGNMENT.ADD_SET')"
      @click="addSet"
    />

    <fieldset class="m-0 flex flex-col gap-2 border-0 p-0">
      <legend class="mb-1 text-xs font-medium text-n-slate-11">
        {{ $t('INBOX_TEAM_ASSIGNMENT.MODE') }}
      </legend>
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <input v-model="mode" type="radio" value="add" class="accent-n-brand" />
        {{ $t('INBOX_TEAM_ASSIGNMENT.MODE_ADD') }}
      </label>
      <label class="flex items-center gap-2 text-sm text-n-slate-12">
        <input
          v-model="mode"
          type="radio"
          value="replace"
          class="accent-n-brand"
        />
        {{ $t('INBOX_TEAM_ASSIGNMENT.MODE_REPLACE') }}
      </label>
    </fieldset>

    <p class="mb-0 text-sm text-n-slate-12">
      <span class="font-medium">{{ summary }}</span>
      <span v-if="validationMessage" class="mt-1 block text-n-ruby-11">
        {{ validationMessage }}
      </span>
    </p>
  </Dialog>

  <AssignTeamsSourcePicker
    ref="pickerRef"
    :inboxes="inboxes"
    :unavailable-ids="unavailableIds"
    :set-number="activeSetNumber"
    @apply="applySources"
  />
</template>
