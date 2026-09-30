<script>
import { mapGetters } from 'vuex';
import SettingIntroBanner from 'dashboard/components/widgets/SettingIntroBanner.vue';
import SpinnerLoader from 'dashboard/components-next/spinner/Spinner.vue';

export default {
  components: {
    SettingIntroBanner,
    SpinnerLoader,
  },
  data() {
    return {
      selectedTabIndex: 0,
    };
  },
  computed: {
    ...mapGetters({
      uiFlags: 'teams/getUIFlags',
    }),
    teamId() {
      return this.$route.params.teamId;
    },
    team() {
      return this.$store.getters['teams/getTeam'](this.teamId);
    },
    tabs() {
      return [
        {
          key: 'settings',
          name: this.$t('TEAMS_SETTINGS.EDIT_FLOW.EDIT_WIZARD_DETAILS.TITLE'),
          route: 'settings_teams_edit',
        },
        {
          key: 'agents',
          name: this.$t('TEAMS_SETTINGS.EDIT_FLOW.EDIT_WIZARD_AGENTS.TITLE'),
          route: 'settings_teams_edit_members',
        },
      ];
    },
  },
  watch: {
    '$route.name': {
      immediate: true,
      handler() {
        this.setTabFromRoute();
      },
    },
  },
  mounted() {
    this.$store.dispatch('teams/get');
  },
  methods: {
    setTabFromRoute() {
      const index = this.tabs.findIndex(tab => tab.route === this.$route.name);
      this.selectedTabIndex = index === -1 ? 0 : index;
    },
    onTabChange(selectedTabIndex) {
      const tab = this.tabs[selectedTabIndex];
      if (!tab || tab.route === this.$route.name) return;

      this.$router.push({
        name: tab.route,
        params: { teamId: this.teamId },
      });
    },
  },
};
</script>

<template>
  <div
    v-if="uiFlags.isFetching"
    class="flex items-center justify-center h-full w-full"
  >
    <SpinnerLoader :size="28" class="text-n-blue-11" />
  </div>
  <div
    v-else
    class="grid grid-rows-[auto_1fr] h-full flex-grow flex-shrink pr-0 pl-0 w-full min-w-0"
  >
    <SettingIntroBanner :header-title="team.name">
      <woot-tabs
        class="[&_ul]:p-0 top-px relative"
        :index="selectedTabIndex"
        :border="false"
        @change="onTabChange"
      >
        <woot-tabs-item
          v-for="(tab, index) in tabs"
          :key="tab.key"
          :index="index"
          :name="tab.name"
          :show-badge="false"
          is-compact
        />
      </woot-tabs>
    </SettingIntroBanner>
    <section class="w-full overflow-auto py-8">
      <div class="max-w-4xl mx-auto w-full px-6">
        <router-view />
      </div>
    </section>
  </div>
</template>
