import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ReportsFiltersTeams from '../../Filters/Teams.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';

const teams = [
  { id: 1, name: 'Team 1' },
  { id: 2, name: 'Team 2' },
];

const mountParams = {
  global: {
    mocks: {
      $t: msg => msg,
    },
  },
};

describe('ReportsFiltersTeams.vue', () => {
  let store;
  let teamsModule;

  const mountComponent = (props = {}) =>
    shallowMount(ReportsFiltersTeams, {
      props,
      global: {
        plugins: [store],
        ...mountParams.global,
      },
    });

  beforeEach(() => {
    teamsModule = {
      namespaced: true,
      getters: {
        getTeams: () => teams,
      },
      actions: {
        get: vi.fn(),
      },
    };

    store = createStore({
      modules: {
        teams: teamsModule,
      },
    });
  });

  it('dispatches "teams/get" action when component is mounted', () => {
    mountComponent();
    expect(teamsModule.actions.get).toHaveBeenCalled();
  });

  it('emits "teamFilterSelection" event when an option is added', async () => {
    const wrapper = mountComponent();

    await wrapper.findComponent(TagInput).vm.$emit('add', { value: '1' });

    expect(wrapper.emitted('teamFilterSelection')).toBeTruthy();
    expect(wrapper.emitted('teamFilterSelection')[0]).toEqual([[teams[0]]]);
  });

  it('emits "teamFilterSelection" event without the removed option', async () => {
    const wrapper = mountComponent({ selectedTeam: teams });

    await wrapper.findComponent(TagInput).vm.$emit('remove', 0);

    expect(wrapper.emitted('teamFilterSelection')[0]).toEqual([[teams[1]]]);
  });

  it('only offers options that are not selected yet', () => {
    const wrapper = mountComponent({ selectedTeam: [teams[0]] });
    const tagInput = wrapper.findComponent(TagInput);

    expect(tagInput.props('modelValue')).toEqual([teams[0].name]);
    expect(tagInput.props('menuItems')).toEqual([
      { action: 'select', value: '2', label: teams[1].name },
    ]);
  });
});
