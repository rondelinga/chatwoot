<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';

import InboxTeamsAPI from '../../../../api/inboxTeams';
import NextButton from 'dashboard/components-next/button/Button.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';
import router from '../../../index';
import PageHeader from '../SettingsSubPageHeader.vue';
import { useVuelidate } from '@vuelidate/core';

export default {
  components: {
    PageHeader,
    NextButton,
    TagInput,
  },
  validations: {
    selectedTeamIds: {
      isEmpty() {
        return !!this.selectedTeamIds.length;
      },
    },
  },
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      selectedTeamIds: [],
      teamConfigs: {},
      defaultTeamId: null,
      isCreating: false,
    };
  },
  computed: {
    ...mapGetters({
      teamList: 'teams/getTeams',
      routingTypes: 'routingTypes/getRoutingTypes',
      agentBots: 'agentBots/getBots',
    }),
    selectedTeamNames() {
      return this.selectedTeamIds.map(
        id => this.teamList.find(team => team.id === id)?.name ?? ''
      );
    },
    selectedTeams() {
      return this.selectedTeamIds
        .map(id => this.teamList.find(team => team.id === id))
        .filter(Boolean);
    },
    teamMenuItems() {
      return this.teamList
        .filter(({ id }) => !this.selectedTeamIds.includes(id))
        .map(({ id, name }) => ({
          label: name,
          value: id,
          action: 'select',
        }));
    },
  },
  async mounted() {
    await Promise.all([
      this.$store.dispatch('teams/get'),
      this.$store.dispatch('routingTypes/get'),
      this.$store.dispatch('agentBots/get'),
    ]);
  },
  methods: {
    ensureTeamConfig(teamId) {
      if (!this.teamConfigs[teamId]) {
        this.teamConfigs[teamId] = { routing_type_id: '', agent_bot_id: '' };
      }
    },
    handleTeamAdd({ value }) {
      if (this.selectedTeamIds.includes(value)) return;

      this.selectedTeamIds.push(value);
      this.ensureTeamConfig(value);
      if (!this.defaultTeamId) this.defaultTeamId = value;
    },
    handleTeamRemove(index) {
      const [removedId] = this.selectedTeamIds.splice(index, 1);
      delete this.teamConfigs[removedId];
      if (this.defaultTeamId === removedId) this.defaultTeamId = null;
    },
    async addTeams() {
      this.v$.$touch();
      if (this.v$.selectedTeamIds.$invalid) return;
      if (!this.defaultTeamId) {
        useAlert(this.$t('INBOX_MGMT.TEAMS.ROUTING.DEFAULT_TEAM_REQUIRED'));
        return;
      }

      this.isCreating = true;
      const inboxId = this.$route.params.inbox_id;
      const teamConfigs = this.selectedTeamIds.map(teamId => ({
        team_id: teamId,
        is_default: teamId === this.defaultTeamId,
        routing_type_id: this.teamConfigs[teamId]?.routing_type_id || null,
        agent_bot_id: this.teamConfigs[teamId]?.agent_bot_id || null,
      }));

      try {
        await InboxTeamsAPI.update({ inboxId, teamConfigs });
        router.replace({
          name: 'settings_inbox_finish',
          params: {
            page: 'new',
            inbox_id: this.$route.params.inbox_id,
          },
        });
      } catch (error) {
        useAlert(error.message);
      }
      this.isCreating = false;
    },
  },
};
</script>

<template>
  <div class="h-full w-full p-6 col-span-6">
    <form class="flex flex-wrap flex-col mx-0" @submit.prevent="addTeams()">
      <div class="w-full">
        <PageHeader
          :header-title="$t('INBOX_MGMT.TEAMS.ADD_TITLE')"
          :header-content="$t('INBOX_MGMT.TEAMS.ADD_DESC')"
        />
      </div>
      <div>
        <div class="w-full mb-4">
          <label :class="{ error: v$.selectedTeamIds.$error }">
            {{ $t('INBOX_MGMT.TEAMS.TITLE') }}
            <div
              data-testid="agent-selector"
              class="rounded-xl outline outline-1 -outline-offset-1 outline-n-weak hover:outline-n-strong px-2 py-2"
            >
              <TagInput
                :model-value="selectedTeamNames"
                :placeholder="$t('INBOX_MGMT.TEAMS.PICK_TEAMS')"
                :menu-items="teamMenuItems"
                show-dropdown
                skip-label-dedup
                :auto-open-dropdown="false"
                @add="handleTeamAdd"
                @remove="handleTeamRemove"
              />
            </div>
            <span v-if="v$.selectedTeamIds.$error" class="message">
              {{ $t('INBOX_MGMT.TEAMS.VALIDATION_ERROR') }}
            </span>
          </label>
        </div>

        <div v-if="selectedTeams.length" class="w-full mb-4">
          <table class="w-full border-collapse table-fixed">
            <colgroup>
              <col class="w-[26%]" />
              <col class="w-[30%]" />
              <col class="w-[30%]" />
              <col class="w-[14%]" />
            </colgroup>
            <thead>
              <tr class="border-b border-n-weak">
                <th
                  class="px-3 pb-3 text-left text-xs font-medium text-n-slate-11"
                >
                  {{ $t('INBOX_MGMT.TEAMS.ROUTING.TEAM') }}
                </th>
                <th
                  class="px-3 pb-3 text-left text-xs font-medium text-n-slate-11"
                >
                  {{ $t('INBOX_MGMT.TEAMS.ROUTING.ROUTING_TYPE') }}
                </th>
                <th
                  class="px-3 pb-3 text-left text-xs font-medium text-n-slate-11"
                >
                  {{ $t('INBOX_MGMT.TEAMS.ROUTING.BOT') }}
                </th>
                <th
                  class="px-3 pb-3 text-center text-xs font-medium text-n-slate-11"
                >
                  {{ $t('INBOX_MGMT.TEAMS.ROUTING.DEFAULT') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="team in selectedTeams" :key="team.id">
                <td class="px-3 pt-4 text-sm text-n-slate-12 truncate">
                  {{ team.name }}
                </td>
                <td class="px-3 pt-4">
                  <div
                    v-if="teamConfigs[team.id]"
                    class="rounded-lg outline outline-1 -outline-offset-1 outline-n-weak hover:outline-n-strong"
                  >
                    <select
                      v-model="teamConfigs[team.id].routing_type_id"
                      class="reset-base !mb-0 !border-0 !outline-none !bg-transparent !shadow-none !py-2.5 !px-3 !h-auto !leading-normal text-sm text-n-slate-12"
                    >
                      <option value="">
                        {{ $t('INBOX_MGMT.TEAMS.ROUTING.NO_ROUTING_TYPE') }}
                      </option>
                      <option
                        v-for="routingType in routingTypes"
                        :key="routingType.id"
                        :value="routingType.id"
                      >
                        {{ routingType.name }}
                      </option>
                    </select>
                  </div>
                </td>
                <td class="px-3 pt-4">
                  <div
                    v-if="teamConfigs[team.id]"
                    class="rounded-lg outline outline-1 -outline-offset-1 outline-n-weak hover:outline-n-strong"
                  >
                    <select
                      v-model="teamConfigs[team.id].agent_bot_id"
                      class="reset-base !mb-0 !border-0 !outline-none !bg-transparent !shadow-none !py-2.5 !px-3 !h-auto !leading-normal text-sm text-n-slate-12"
                    >
                      <option value="">
                        {{ $t('INBOX_MGMT.TEAMS.ROUTING.NO_BOT') }}
                      </option>
                      <option
                        v-for="bot in agentBots"
                        :key="bot.id"
                        :value="bot.id"
                      >
                        {{ bot.name }}
                      </option>
                    </select>
                  </div>
                </td>
                <td class="px-3 pt-4">
                  <div class="flex justify-center">
                    <input
                      v-model="defaultTeamId"
                      type="radio"
                      name="defaultTeam"
                      :value="team.id"
                      class="w-4 h-4 cursor-pointer accent-n-teal-9"
                    />
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="w-full">
          <NextButton
            type="submit"
            :is-loading="isCreating"
            solid
            blue
            :label="$t('INBOX_MGMT.TEAMS.BUTTON_TEXT')"
          />
        </div>
      </div>
    </form>
  </div>
</template>
