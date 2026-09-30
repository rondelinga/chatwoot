<script setup>
import { computed } from 'vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Avatar from 'next/avatar/Avatar.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import BaseTable from 'dashboard/components-next/table/BaseTable.vue';
import BaseTableRow from 'dashboard/components-next/table/BaseTableRow.vue';
import BaseTableCell from 'dashboard/components-next/table/BaseTableCell.vue';
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

const selectedAgentCount = computed(
  () => props.primaryAgents.length + props.backupAgents.length
);

const disableSubmitButton = computed(() => selectedAgentCount.value === 0);

const isPrimarySelected = agentId => props.primaryAgents.includes(agentId);
const isBackupSelected = agentId => props.backupAgents.includes(agentId);

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

const headers = computed(() => [
  t('TEAMS_SETTINGS.AGENTS.PRIMARY'),
  t('TEAMS_SETTINGS.AGENTS.BACKUP'),
  t('TEAMS_SETTINGS.AGENTS.AGENT'),
  t('TEAMS_SETTINGS.AGENTS.EMAIL'),
]);
</script>

<template>
  <BaseTable :headers="headers" :items="agentList">
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
