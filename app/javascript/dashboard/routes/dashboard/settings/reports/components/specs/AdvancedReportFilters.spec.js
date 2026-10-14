import { flushPromises, shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import AdvancedReportFilters from '../AdvancedReportFilters.vue';
import AddFilterChip from '../Filters/v3/AddFilterChip.vue';
import ActiveFilterChip from '../Filters/v3/ActiveFilterChip.vue';
import SelectedFilterChip from '../Filters/v3/SelectedFilterChip.vue';
import TimeRangeFilterChip from '../Filters/v3/TimeRangeFilterChip.vue';
import ReportFilterPresets from '../ReportFilterPresets.vue';
import WootDatePicker from 'dashboard/components/ui/DatePicker/DatePicker.vue';
import FilterButton from 'dashboard/components/ui/Dropdown/DropdownButton.vue';
import { GROUP_BY_FILTER } from '../../constants';

const agents = [
  { id: 1, name: 'Alice' },
  { id: 2, name: 'Bob' },
];
const labels = [{ id: 7, title: 'billing' }];
const inboxes = [{ id: 3, name: 'Website' }];

describe('AdvancedReportFilters.vue', () => {
  let store;
  let entityActions;

  const createTestStore = (reportFilters = {}) => {
    entityActions = {
      'agents/get': vi.fn(),
      'inboxes/get': vi.fn(),
      'teams/get': vi.fn(),
      'labels/get': vi.fn(),
    };
    return createStore({
      state: { reportFilters },
      getters: {
        getReportFilters: state => state.reportFilters,
        'agents/getAgents': () => agents,
        'inboxes/getInboxes': () => inboxes,
        'teams/getTeams': () => [],
        'labels/getLabels': () => labels,
      },
      mutations: {
        setReportFilters(state, filters) {
          state.reportFilters = { ...state.reportFilters, ...filters };
        },
      },
      actions: {
        updateReportFilters: ({ commit }, filters) =>
          commit('setReportFilters', filters),
        ...entityActions,
      },
    });
  };

  const mountComponent = (props = {}) =>
    shallowMount(AdvancedReportFilters, {
      props,
      global: { plugins: [store] },
    });

  const lastPayload = wrapper => wrapper.emitted('filterChange').at(-1)[0];

  beforeEach(() => {
    store = createTestStore();
  });

  it('emits today with hourly grouping and the full day in UTC on mount', () => {
    const wrapper = mountComponent({ showGroupByFilter: true });
    const now = new Date();
    const dayStart =
      Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()) / 1000;

    expect(lastPayload(wrapper)).toEqual({
      from: dayStart,
      to: dayStart + 23 * 3600 + 59 * 60,
      groupBy: GROUP_BY_FILTER[5],
      businessHours: false,
      selectedAgents: [],
      selectedInbox: [],
      selectedTeam: [],
      selectedLabel: [],
      timeRange: { since: '00:00', until: '23:59' },
    });
  });

  it('fetches only the entities of the visible filters', () => {
    mountComponent({ showAgentsFilter: true, showLabelsFilter: true });

    expect(entityActions['agents/get']).toHaveBeenCalled();
    expect(entityActions['labels/get']).toHaveBeenCalled();
    expect(entityActions['inboxes/get']).not.toHaveBeenCalled();
    expect(entityActions['teams/get']).not.toHaveBeenCalled();
  });

  it('adds and removes multiple entities of the same type', async () => {
    const wrapper = mountComponent({ showAgentsFilter: true });
    const addFilterChip = wrapper.findComponent(AddFilterChip);

    addFilterChip.vm.$emit('addFilter', { id: 1, type: 'agents' });
    addFilterChip.vm.$emit('addFilter', { id: 2, type: 'agents' });
    await wrapper.vm.$nextTick();

    expect(lastPayload(wrapper).selectedAgents).toEqual(agents);
    const chips = wrapper.findAllComponents(SelectedFilterChip);
    expect(chips.map(chip => chip.props('name'))).toEqual(['Alice', 'Bob']);
    expect(
      addFilterChip.props('menuOption').find(item => item.type === 'agents')
        .options
    ).toEqual([]);

    chips[0].vm.$emit('remove');
    await wrapper.vm.$nextTick();

    expect(lastPayload(wrapper).selectedAgents).toEqual([agents[1]]);
  });

  it('applies the time range to from and to', async () => {
    const wrapper = mountComponent({ showTimeRangeFilter: true });
    const initial = lastPayload(wrapper);

    wrapper
      .findComponent(TimeRangeFilterChip)
      .vm.$emit('change', { since: '09:00', until: '18:30' });
    await wrapper.vm.$nextTick();

    const payload = lastPayload(wrapper);
    expect(payload.timeRange).toEqual({ since: '09:00', until: '18:30' });
    expect(payload.from).toBe(initial.from + 9 * 3600);
    expect(payload.to).toBe(initial.from + 18 * 3600 + 30 * 60);
  });

  it('limits grouping to the options of the selected range', async () => {
    const wrapper = mountComponent({ showGroupByFilter: true });
    expect(wrapper.findComponent(ActiveFilterChip).exists()).toBe(false);

    wrapper
      .findComponent(WootDatePicker)
      .vm.$emit('dateRangeChanged', [
        new Date(2024, 0, 1),
        new Date(2024, 0, 30),
        'last30days',
      ]);
    await wrapper.vm.$nextTick();

    expect(lastPayload(wrapper).groupBy).toEqual(GROUP_BY_FILTER[1]);
    const groupByChip = wrapper.findComponent(ActiveFilterChip);
    expect(groupByChip.props('options').map(option => option.id)).toEqual([
      1, 2,
    ]);

    groupByChip.vm.$emit('addFilter', { id: 2 });
    await wrapper.vm.$nextTick();

    expect(lastPayload(wrapper).groupBy).toEqual(GROUP_BY_FILTER[2]);
  });

  it('restores the filters saved in the store', () => {
    const customDateRange = [new Date(2024, 0, 1), new Date(2024, 0, 10)];
    store = createTestStore({
      selectedDateRange: 'custom',
      customDateRange,
      selectedGroupByFilter: GROUP_BY_FILTER[2],
      businessHoursSelected: true,
      selectedAgents: [agents[0]],
      selectedLabel: labels,
      selectedTimeRange: { since: '08:00', until: '17:00' },
    });

    const wrapper = mountComponent({
      showAgentsFilter: true,
      showLabelsFilter: true,
    });

    expect(lastPayload(wrapper)).toMatchObject({
      from: Date.UTC(2024, 0, 1, 8) / 1000,
      to: Date.UTC(2024, 0, 10, 17) / 1000,
      groupBy: GROUP_BY_FILTER[2],
      businessHours: true,
      selectedAgents: [agents[0]],
      selectedLabel: labels,
    });
    expect(
      wrapper
        .findAllComponents(SelectedFilterChip)
        .map(chip => chip.props('name'))
    ).toEqual(['Alice', 'billing']);
  });

  it('saves the current filters to the store', async () => {
    const wrapper = mountComponent({ showAgentsFilter: true });

    wrapper
      .findComponent(AddFilterChip)
      .vm.$emit('addFilter', { id: 2, type: 'agents' });
    await wrapper.vm.$nextTick();

    expect(store.getters.getReportFilters).toMatchObject({
      selectedDateRange: 'today',
      selectedAgents: [agents[1]],
      selectedTimeRange: { since: '00:00', until: '23:59' },
    });
  });

  it('clears all visible entity filters', async () => {
    store = createTestStore({ selectedAgents: agents });
    const wrapper = mountComponent({ showAgentsFilter: true });

    wrapper.findComponent(FilterButton).vm.$emit('click');
    await wrapper.vm.$nextTick();

    expect(lastPayload(wrapper).selectedAgents).toEqual([]);
  });

  describe('filter presets', () => {
    it('shows presets only for pages with a section', () => {
      expect(mountComponent().findComponent(ReportFilterPresets).exists()).toBe(
        false
      );
      expect(
        mountComponent({ section: 'conversation' })
          .findComponent(ReportFilterPresets)
          .exists()
      ).toBe(true);
    });

    it('saves the current filters with the page filters', async () => {
      store = createTestStore({
        selectedDateRange: 'custom',
        customDateRange: [
          new Date(Date.UTC(2024, 0, 1)),
          new Date(Date.UTC(2024, 0, 10)),
        ],
        selectedGroupByFilter: GROUP_BY_FILTER[2],
        businessHoursSelected: true,
        selectedAgents: [agents[1]],
        selectedLabel: labels,
      });
      const wrapper = mountComponent({
        section: 'csat',
        showAgentsFilter: true,
        extraFilters: { inbox_id: [3], rating: 4 },
      });

      expect(
        wrapper.findComponent(ReportFilterPresets).props('filters')
      ).toEqual({
        rangeType: 'custom',
        dateRangeId: 'CUSTOM_DATE_RANGE',
        customDateRange: [
          '2024-01-01T00:00:00.000Z',
          '2024-01-10T00:00:00.000Z',
        ],
        groupById: 2,
        businessHours: true,
        timeRange: { since: '00:00', until: '23:59' },
        agentIds: [2],
        inboxIds: [3],
        teamIds: [],
        labelIds: [],
        ratingValue: 4,
        extra: { inbox_id: [3], rating: 4 },
      });
    });

    it('applies a preset to the filters and the page filters', async () => {
      const wrapper = mountComponent({
        section: 'conversation',
        showGroupByFilter: true,
        showAgentsFilter: true,
        showInboxFilter: true,
      });

      wrapper.findComponent(ReportFilterPresets).vm.$emit('apply', {
        rangeType: 'custom',
        customDateRange: [
          '2024-01-01T00:00:00.000Z',
          '2024-02-15T00:00:00.000Z',
        ],
        groupById: 2,
        businessHours: true,
        timeRange: { since: '09:00', until: '18:00' },
        agentIds: [1],
        inboxIds: [3],
        labelIds: [7],
        ratingValue: 5,
        extra: { hideInactive: true },
      });
      await flushPromises();

      expect(entityActions['labels/get']).toHaveBeenCalled();
      expect(wrapper.emitted('applyExtraFilters').at(-1)[0]).toEqual({
        hideInactive: true,
        user_ids: [1],
        inbox_id: [3],
        team_id: [],
        rating: 5,
      });
      expect(lastPayload(wrapper)).toEqual({
        from: Date.UTC(2024, 0, 1, 9) / 1000,
        to: Date.UTC(2024, 1, 15, 18) / 1000,
        groupBy: GROUP_BY_FILTER[2],
        businessHours: true,
        selectedAgents: [agents[0]],
        selectedInbox: inboxes,
        selectedTeam: [],
        selectedLabel: [],
        timeRange: { since: '09:00', until: '18:00' },
      });
    });

    it('recalculates relative ranges of presets saved by the old filters', async () => {
      const wrapper = mountComponent({
        section: 'conversation',
        showGroupByFilter: true,
      });

      wrapper.findComponent(ReportFilterPresets).vm.$emit('apply', {
        dateRangeId: 'LAST_30_DAYS',
        customDateRange: [
          '2020-01-01T00:00:00.000Z',
          '2020-01-30T00:00:00.000Z',
        ],
        groupById: 4,
      });
      await flushPromises();

      const today = new Date();
      expect(lastPayload(wrapper).to).toBe(
        Date.UTC(
          today.getFullYear(),
          today.getMonth(),
          today.getDate(),
          23,
          59
        ) / 1000
      );
      expect(lastPayload(wrapper).groupBy).toEqual(GROUP_BY_FILTER[1]);
      expect(store.getters.getReportFilters.selectedDateRange).toBe(
        'last30days'
      );
    });
  });
});
