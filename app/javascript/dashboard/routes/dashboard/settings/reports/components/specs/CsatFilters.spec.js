import { computed } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import CsatFilters from '../Csat/CsatFilters.vue';
import AdvancedReportFilters from '../AdvancedReportFilters.vue';
import ExcludeTagFilter from '../Csat/ExcludeTagFilter.vue';
import SelectedFilterChip from '../Filters/v3/SelectedFilterChip.vue';
import FilterButton from 'dashboard/components/ui/Dropdown/DropdownButton.vue';

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ accountId: computed(() => 1) }),
}));

const agents = [{ id: 1, name: 'Alice' }];
const inboxes = [{ id: 2, name: 'Website' }];

describe('CsatFilters.vue', () => {
  const mountComponent = () =>
    shallowMount(CsatFilters, {
      global: {
        plugins: [
          createStore({
            getters: {
              getCurrentUser: () => ({ accounts: [] }),
              'agents/getAgents': () => agents,
              'inboxes/getInboxes': () => inboxes,
              'teams/getTeams': () => [],
            },
          }),
        ],
      },
    });

  const lastPayload = wrapper => wrapper.emitted('filterChange').at(-1)[0];
  const dateFilters = {
    from: 100,
    to: 200,
    businessHours: false,
    timeRange: { since: '00:00', until: '23:59' },
  };

  it('enables presets for the CSAT page', () => {
    const filters = mountComponent().findComponent(AdvancedReportFilters);

    expect(filters.props('section')).toBe('csat');
    expect(filters.props('extraFilters')).toEqual({
      user_ids: [],
      inbox_id: [],
      team_id: [],
      rating: null,
    });
  });

  it('sends the excluded tags with the filters', async () => {
    const wrapper = mountComponent();

    wrapper.findComponent(ExcludeTagFilter).vm.$emit('update', ['spam']);
    await wrapper.vm.$nextTick();

    expect(lastPayload(wrapper).excludedLabels).toEqual(['spam']);
    expect(wrapper.findComponent(ExcludeTagFilter).props('selected')).toEqual([
      'spam',
    ]);
  });

  it('applies the CSAT filters of a preset', async () => {
    const wrapper = mountComponent();
    const filters = wrapper.findComponent(AdvancedReportFilters);

    filters.vm.$emit('applyExtraFilters', {
      user_ids: [1],
      inbox_id: [2],
      team_id: [],
      rating: 4,
    });
    filters.vm.$emit('filterChange', dateFilters);
    await wrapper.vm.$nextTick();

    expect(lastPayload(wrapper)).toEqual({
      ...dateFilters,
      selectedAgents: [{ id: 1 }],
      selectedInboxes: [{ id: 2 }],
      selectedTeams: [],
      selectedRating: { value: 4 },
      excludedLabels: [],
    });
    expect(
      wrapper
        .findAllComponents(SelectedFilterChip)
        .map(chip => chip.props('name'))
    ).toEqual(['Alice', 'Website', 'CSAT.RATINGS.GOOD']);
  });

  it('clears the excluded tags with the other filters', async () => {
    const wrapper = mountComponent();
    expect(wrapper.findComponent(FilterButton).exists()).toBe(false);

    wrapper.findComponent(ExcludeTagFilter).vm.$emit('update', ['spam']);
    await wrapper.vm.$nextTick();
    wrapper.findComponent(FilterButton).vm.$emit('click');
    await wrapper.vm.$nextTick();

    expect(lastPayload(wrapper).excludedLabels).toEqual([]);
  });
});
