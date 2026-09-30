<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useVuelidate } from '@vuelidate/core';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import PageHeader from '../../SettingsSubPageHeader.vue';
import AgentSelector from '../AgentSelector.vue';

export default {
  components: {
    Spinner,
    PageHeader,
    AgentSelector,
  },
  validations: {
    selectedAgents: {
      isEmpty() {
        return this.primaryAgents.length + this.backupAgents.length > 0;
      },
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      primaryAgents: [],
      backupAgents: [],
      isCreating: false,
    };
  },

  computed: {
    ...mapGetters({
      agentList: 'agents/getAgents',
      uiFlags: 'teamMembers/getUIFlags',
    }),

    teamId() {
      return this.$route.params.teamId;
    },
    headerTitle() {
      return this.$t('TEAMS_SETTINGS.EDIT_FLOW.AGENTS.TITLE', {
        teamName: this.currentTeam.name,
      });
    },
    currentTeam() {
      return this.$store.getters['teams/getTeam'](this.teamId);
    },
    teamMembers() {
      return this.$store.getters['teamMembers/getTeamMembers'](this.teamId);
    },
    showAgentsList() {
      const { id } = this.currentTeam;
      return id && !this.uiFlags.isFetching;
    },
  },

  async mounted() {
    const { teamId } = this.$route.params;
    this.$store.dispatch('agents/get');
    try {
      await this.$store.dispatch('teamMembers/get', {
        teamId,
      });
      this.primaryAgents = this.teamMembers
        .filter(member => member.assignment_tier === 'primary')
        .map(member => member.id);
      this.backupAgents = this.teamMembers
        .filter(member => member.assignment_tier === 'backup')
        .map(member => member.id);
    } catch {
      this.primaryAgents = [];
      this.backupAgents = [];
    }
  },

  methods: {
    updateAgents({ primary, backup }) {
      this.v$.selectedAgents.$touch();
      this.primaryAgents = [...primary];
      this.backupAgents = [...backup];
    },
    async addAgents() {
      this.isCreating = true;
      const { teamId, primaryAgents, backupAgents } = this;

      try {
        await this.$store.dispatch('teamMembers/update', {
          teamId,
          primaryUserIds: primaryAgents,
          backupUserIds: backupAgents,
        });
        useAlert(this.$t('TEAMS_SETTINGS.EDIT.API.AGENTS_SUCCESS_MESSAGE'));
        this.$store.dispatch('teams/get');
      } catch (error) {
        useAlert(error.message);
      }
      this.isCreating = false;
    },
  },
};
</script>

<template>
  <form class="flex flex-col gap-4 mx-0" @submit.prevent="addAgents">
    <PageHeader
      :header-title="headerTitle"
      :header-content="$t('TEAMS_SETTINGS.EDIT_FLOW.AGENTS.DESC')"
    />

    <div class="w-full h-full">
      <div v-if="v$.selectedAgents.$error">
        <p class="error-message pb-2">
          {{ $t('TEAMS_SETTINGS.ADD.AGENT_VALIDATION_ERROR') }}
        </p>
      </div>
      <AgentSelector
        v-if="showAgentsList"
        :agent-list="agentList"
        :primary-agents="primaryAgents"
        :backup-agents="backupAgents"
        :update-agents="updateAgents"
        :is-working="isCreating"
        :submit-button-text="$t('TEAMS_SETTINGS.EDIT_FLOW.AGENTS.BUTTON_TEXT')"
      />
      <div v-else class="flex items-center justify-center py-6">
        <Spinner class="text-n-blue-11" />
      </div>
    </div>
  </form>
</template>
