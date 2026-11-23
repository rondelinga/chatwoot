<script setup>
import { computed, ref } from 'vue';
import { picoSearch } from '@chatwoot/pico-search';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import SettingsFieldSection from 'dashboard/components-next/Settings/SettingsFieldSection.vue';
import InboxPriorityMembersAPI from 'dashboard/api/inboxPriorityMembers';

const props = defineProps({
  inbox: {
    type: Object,
    default: () => ({}),
  },
  agents: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['updated']);
const { t } = useI18n();

const showUrgentModal = ref(false);
const selectedUrgentIds = ref([]);
const urgentSearchQuery = ref('');
const isSavingUrgent = ref(false);

const filteredUrgentAgents = computed(() => {
  const query = urgentSearchQuery.value.trim();
  if (!query) return props.agents;
  return picoSearch(props.agents, query, ['name', 'email']);
});

const priorityAgents = computed(() =>
  props.agents.filter(agent => agent.urgent)
);

const regularAgents = computed(() =>
  props.agents.filter(agent => !agent.urgent)
);

const openUrgentModal = () => {
  urgentSearchQuery.value = '';
  selectedUrgentIds.value = priorityAgents.value.map(agent => agent.id);
  showUrgentModal.value = true;
};

const closeUrgentModal = () => {
  showUrgentModal.value = false;
};

const saveUrgentCollaborators = async () => {
  isSavingUrgent.value = true;
  try {
    await InboxPriorityMembersAPI.update({
      inboxId: props.inbox.id,
      userIds: selectedUrgentIds.value,
    });
    const urgentIds = new Set(selectedUrgentIds.value);
    emit(
      'updated',
      props.agents.map(agent => ({
        ...agent,
        urgent: urgentIds.has(agent.id),
      }))
    );
    showUrgentModal.value = false;
    useAlert(t('INBOX_MGMT.TEAMS.URGENT.SUCCESS'));
  } catch (error) {
    useAlert(t('INBOX_MGMT.TEAMS.URGENT.ERROR'));
  } finally {
    isSavingUrgent.value = false;
  }
};
</script>

<template>
  <SettingsFieldSection
    v-if="agents.length"
    :label="$t('INBOX_MGMT.TEAMS.DERIVED_AGENTS')"
    :help-text="$t('INBOX_MGMT.TEAMS.DERIVED_AGENTS_SUB_TEXT')"
    class="mt-6 [&>div]:!items-start"
  >
    <div v-if="priorityAgents.length">
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-sm text-n-amber-11">
          {{ $t('INBOX_MGMT.TEAMS.URGENT.PRIORITY_FOR') }}
        </span>
        <span
          v-for="agent in priorityAgents"
          :key="agent.id"
          class="px-2 py-1 text-sm rounded-lg bg-n-alpha-2 text-n-slate-12"
        >
          {{ agent.name }}
        </span>
      </div>
      <div v-if="regularAgents.length" class="my-3 border-b border-n-weak" />
    </div>
    <div v-if="regularAgents.length" class="flex flex-wrap gap-2">
      <span
        v-for="agent in regularAgents"
        :key="agent.id"
        class="px-2 py-1 text-sm rounded-lg bg-n-alpha-2 text-n-slate-12"
      >
        {{ agent.name }}
      </span>
    </div>
    <div class="mt-4 flex justify-end">
      <NextButton
        :label="$t('INBOX_MGMT.TEAMS.URGENT.BUTTON')"
        @click="openUrgentModal"
      />
    </div>
  </SettingsFieldSection>

  <woot-modal
    v-if="showUrgentModal"
    :show="showUrgentModal"
    :on-close="closeUrgentModal"
  >
    <div class="p-6">
      <h3 class="text-lg font-medium text-n-slate-12 mb-2">
        {{ $t('INBOX_MGMT.TEAMS.URGENT.TITLE') }}
      </h3>
      <p class="text-sm text-n-slate-11 mb-4">
        {{ $t('INBOX_MGMT.TEAMS.URGENT.DESCRIPTION') }}
      </p>
      <Input
        v-model="urgentSearchQuery"
        :placeholder="$t('INBOX_MGMT.TEAMS.URGENT.SEARCH_PLACEHOLDER')"
        class="group mb-4 w-full [&>input]:!ps-8 [&>input]:!rounded-[0.625rem]"
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
      <p
        v-if="!filteredUrgentAgents.length"
        class="text-sm text-n-slate-11 mb-2"
      >
        {{ $t('INBOX_MGMT.TEAMS.URGENT.NO_RESULTS') }}
      </p>
      <ul v-else class="max-h-80 overflow-y-auto">
        <li
          v-for="agent in filteredUrgentAgents"
          :key="agent.id"
          class="flex items-center gap-3 py-2"
        >
          <input
            :id="`urgent-collaborator-${agent.id}`"
            v-model="selectedUrgentIds"
            type="checkbox"
            :value="agent.id"
            class="w-4 h-4 cursor-pointer accent-n-teal-9"
          />
          <label
            :for="`urgent-collaborator-${agent.id}`"
            class="min-w-0 cursor-pointer"
          >
            <span class="block text-sm text-n-slate-12 truncate">
              {{ agent.name }}
            </span>
            <span class="block text-xs text-n-slate-11 truncate">
              {{ agent.email || '---' }}
            </span>
          </label>
        </li>
      </ul>
      <div class="flex justify-end gap-2 mt-6">
        <NextButton
          color="slate"
          :label="$t('INBOX_MGMT.TEAMS.URGENT.CANCEL')"
          @click="closeUrgentModal"
        />
        <NextButton
          :label="$t('INBOX_MGMT.TEAMS.URGENT.SAVE')"
          :is-loading="isSavingUrgent"
          @click="saveUrgentCollaborators"
        />
      </div>
    </div>
  </woot-modal>
</template>
