<script>
/* eslint no-console: 0 */
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
      isCreating: false,
    };
  },
  computed: {
    ...mapGetters({
      teamList: 'teams/getTeams',
    }),
    selectedTeamNames() {
      return this.selectedTeamIds.map(
        id => this.teamList.find(team => team.id === id)?.name ?? ''
      );
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
    await this.$store.dispatch('teams/get');
  },
  methods: {
    handleTeamAdd({ value }) {
      if (!this.selectedTeamIds.includes(value)) {
        this.selectedTeamIds.push(value);
      }
    },
    handleTeamRemove(index) {
      this.selectedTeamIds.splice(index, 1);
    },
    async addTeams() {
      this.isCreating = true;
      const inboxId = this.$route.params.inbox_id;

      try {
        await InboxTeamsAPI.update({
          inboxId,
          teamList: this.selectedTeamIds,
        });
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
                @add="handleTeamAdd"
                @remove="handleTeamRemove"
              />
            </div>
            <span v-if="v$.selectedTeamIds.$error" class="message">
              {{ $t('INBOX_MGMT.TEAMS.VALIDATION_ERROR') }}
            </span>
          </label>
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
