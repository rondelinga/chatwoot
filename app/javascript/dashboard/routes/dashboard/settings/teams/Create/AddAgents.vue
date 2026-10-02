<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

import router from '../../../../index';
import PageHeader from '../../SettingsSubPageHeader.vue';
import AgentSelector from '../AgentSelector.vue';
import { useVuelidate } from '@vuelidate/core';

export default {
  components: {
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
    }),

    teamId() {
      return this.$route.params.teamId;
    },
    headerTitle() {
      return this.$t('TEAMS_SETTINGS.ADD.TITLE', {
        teamName: this.currentTeam.name,
      });
    },
    currentTeam() {
      return this.$store.getters['teams/getTeam'](this.teamId);
    },
  },

  mounted() {
    this.$store.dispatch('agents/get');
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
        await this.$store.dispatch('teamMembers/create', {
          teamId,
          primaryUserIds: primaryAgents,
          backupUserIds: backupAgents,
        });
        router.replace({
          name: 'settings_teams_finish',
          params: {
            page: 'new',
            teamId,
          },
        });
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
  <div class="h-full w-full px-8 pt-8 col-span-6 overflow-auto">
    <form class="flex flex-col gap-4 mx-0" @submit.prevent="addAgents">
      <PageHeader
        :header-title="headerTitle"
        :header-content="$t('TEAMS_SETTINGS.ADD.DESC')"
      />

      <div class="w-full h-full">
        <div v-if="v$.selectedAgents.$error">
          <p class="error-message pb-2">
            {{ $t('TEAMS_SETTINGS.ADD.AGENT_VALIDATION_ERROR') }}
          </p>
        </div>
        <AgentSelector
          :agent-list="agentList"
          :primary-agents="primaryAgents"
          :backup-agents="backupAgents"
          :update-agents="updateAgents"
          :is-working="isCreating"
          :submit-button-text="$t('TEAMS_SETTINGS.ADD.BUTTON_TEXT')"
        />
      </div>
    </form>
  </div>
</template>
