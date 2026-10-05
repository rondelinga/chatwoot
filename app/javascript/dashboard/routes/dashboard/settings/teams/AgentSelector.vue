<script setup>
import { computed, ref } from 'vue';
import { picoSearch } from '@chatwoot/pico-search';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Avatar from 'next/avatar/Avatar.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import BaseTable from 'dashboard/components-next/table/BaseTable.vue';
import BaseTableRow from 'dashboard/components-next/table/BaseTableRow.vue';
import BaseTableCell from 'dashboard/components-next/table/BaseTableCell.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  agentList: {
    type: Array,
    default: () => [],
  },
  primaryAgents: {
    type: Array,
    default: () => [],
  },
  backupAgents: {
    type: Array,
    default: () => [],
  },
  updateAgents: {
    type: Function,
    default: () => {},
  },
  isWorking: {
    type: Boolean,
    default: false,
  },
  submitButtonText: {
    type: String,
    default: '',
  },
});

const { t } = useI18n();
const searchQuery = ref('');

const filteredAgents = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return props.agentList;
  return picoSearch(props.agentList, query, ['name', 'email']);
});

const visibleIds = computed(() => filteredAgents.value.map(agent => agent.id));

const selectedAgentCount = computed(
  () => props.primaryAgents.length + props.backupAgents.length
);

const disableSubmitButton = computed(() => selectedAgentCount.value === 0);

const isPrimarySelected = agentId => props.primaryAgents.includes(agentId);
const isBackupSelected = agentId => props.backupAgents.includes(agentId);

const areAllVisibleSelected = selectedIds =>
  visibleIds.value.length > 0 &&
  visibleIds.value.every(id => selectedIds.includes(id));

const areSomeVisibleSelected = selectedIds =>
  !areAllVisibleSelected(selectedIds) &&
  visibleIds.value.some(id => selectedIds.includes(id));

const areAllVisiblePrimary = computed(() =>
  areAllVisibleSelected(props.primaryAgents)
);
const areAllVisibleBackup = computed(() =>
  areAllVisibleSelected(props.backupAgents)
);
const isSomeVisiblePrimary = computed(() =>
  areSomeVisibleSelected(props.primaryAgents)
);
const isSomeVisibleBackup = computed(() =>
  areSomeVisibleSelected(props.backupAgents)
);

const handlePrimarySelect = agentId => {
  const primary = isPrimarySelected(agentId)
    ? props.primaryAgents.filter(id => id !== agentId)
    : [...props.primaryAgents, agentId];
  const backup = props.backupAgents.filter(id => id !== agentId);

  props.updateAgents({ primary, backup });
};

const handleBackupSelect = agentId => {
  const backup = isBackupSelected(agentId)
    ? props.backupAgents.filter(id => id !== agentId)
    : [...props.backupAgents, agentId];
  const primary = props.primaryAgents.filter(id => id !== agentId);

  props.updateAgents({ primary, backup });
};

const toggleAllPrimary = event => {
  const idsToToggle = visibleIds.value;

  if (event.target.checked) {
    props.updateAgents({
      primary: [...new Set([...props.primaryAgents, ...idsToToggle])],
      backup: props.backupAgents.filter(id => !idsToToggle.includes(id)),
    });
    return;
  }

  props.updateAgents({
    primary: props.primaryAgents.filter(id => !idsToToggle.includes(id)),
    backup: props.backupAgents,
  });
};

const toggleAllBackup = event => {
  const idsToToggle = visibleIds.value;

  if (event.target.checked) {
    props.updateAgents({
      primary: props.primaryAgents.filter(id => !idsToToggle.includes(id)),
      backup: [...new Set([...props.backupAgents, ...idsToToggle])],
    });
    return;
  }

  props.updateAgents({
    primary: props.primaryAgents,
    backup: props.backupAgents.filter(id => !idsToToggle.includes(id)),
  });
};

const headers = computed(() => [
  t('TEAMS_SETTINGS.AGENTS.PRIMARY'),
  t('TEAMS_SETTINGS.AGENTS.BACKUP'),
  t('TEAMS_SETTINGS.AGENTS.AGENT'),
  t('TEAMS_SETTINGS.AGENTS.EMAIL'),
]);
</script>

<template>
  <Input
    v-model="searchQuery"
    :placeholder="t('TEAMS_SETTINGS.AGENTS.SEARCH_PLACEHOLDER')"
    class="group mb-4 w-full max-w-sm [&>input]:!ps-8 [&>input]:!rounded-[0.625rem]"
    size="sm"
    type="search"
  >
    <template #prefix>
      <Icon
        icon="i-lucide-search"
        class="absolute top-1/2 -translate-y-1/2 text-n-slate-11 group-focus-within:text-n-brand size-3.5 start-2.5"
      />
    </template>
  </Input>

  <BaseTable
    :headers="headers"
    :items="filteredAgents"
    :no-data-message="t('TEAMS_SETTINGS.AGENTS.NO_RESULTS')"
  >
    <template #header-0>
      <div class="flex items-center gap-2">
        <Checkbox
          :model-value="areAllVisiblePrimary"
          :indeterminate="isSomeVisiblePrimary"
          :disabled="!visibleIds.length"
          :title="t('TEAMS_SETTINGS.AGENTS.SELECT_ALL_PRIMARY')"
          @change="toggleAllPrimary"
        />
        <span>{{ t('TEAMS_SETTINGS.AGENTS.PRIMARY') }}</span>
      </div>
    </template>
    <template #header-1>
      <div class="flex items-center gap-2">
        <Checkbox
          :model-value="areAllVisibleBackup"
          :indeterminate="isSomeVisibleBackup"
          :disabled="!visibleIds.length"
          :title="t('TEAMS_SETTINGS.AGENTS.SELECT_ALL_BACKUP')"
          @change="toggleAllBackup"
        />
        <span>{{ t('TEAMS_SETTINGS.AGENTS.BACKUP') }}</span>
      </div>
    </template>
    <template #row="{ items }">
      <BaseTableRow v-for="agent in items" :key="agent.id" :item="agent">
        <template #default>
          <BaseTableCell class="w-5">
            <div class="flex items-center">
              <Checkbox
                :model-value="isPrimarySelected(agent.id)"
                :title="$t('TEAMS_SETTINGS.AGENTS.SELECT_PRIMARY')"
                @change="() => handlePrimarySelect(agent.id)"
              />
            </div>
          </BaseTableCell>

          <BaseTableCell class="w-5">
            <div class="flex items-center">
              <Checkbox
                :model-value="isBackupSelected(agent.id)"
                :title="$t('TEAMS_SETTINGS.AGENTS.SELECT_BACKUP')"
                @change="() => handleBackupSelect(agent.id)"
              />
            </div>
          </BaseTableCell>

          <BaseTableCell class="min-w-0 max-w-40">
            <div class="flex items-center gap-2 min-w-0">
              <Avatar
                :src="agent.thumbnail"
                :name="agent.name"
                :status="agent.availability_status"
                :size="24"
                hide-offline-status
                rounded-full
                class="flex-shrink-0"
              />
              <h4 class="text-heading-3 mb-0 text-n-slate-12 truncate">
                {{ agent.name }}
              </h4>
            </div>
          </BaseTableCell>

          <BaseTableCell class="min-w-0">
            <span class="text-body-main text-n-slate-11 truncate block">
              {{ agent.email || '---' }}
            </span>
          </BaseTableCell>
        </template>
      </BaseTableRow>
    </template>
  </BaseTable>

  <div
    class="sticky bottom-0 py-4 px-8 -mx-8 z-20 flex items-center justify-between bg-n-surface-1 border-t border-n-weak"
  >
    <p class="text-body-main text-n-slate-11 mb-0">
      {{
        $t('TEAMS_SETTINGS.AGENTS.SELECTED_COUNT', {
          selected: selectedAgentCount,
          total: agentList.length,
        })
      }}
      ·
      {{
        $t('TEAMS_SETTINGS.AGENTS.TIER_COUNT', {
          primary: primaryAgents.length,
          backup: backupAgents.length,
        })
      }}
    </p>
    <NextButton
      type="submit"
      :label="submitButtonText"
      :disabled="disableSubmitButton"
      :is-loading="isWorking"
    />
  </div>
</template>
