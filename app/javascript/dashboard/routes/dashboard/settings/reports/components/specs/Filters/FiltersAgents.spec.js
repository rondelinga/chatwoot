import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ReportsFiltersAgents from '../../Filters/Agents.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';

const agents = [
  { id: 1, name: 'Agent 1' },
  { id: 2, name: 'Agent 2' },
];

const mockStore = createStore({
  modules: {
    agents: {
      namespaced: true,
      state: {
        agents,
      },
      getters: {
        getAgents: state => state.agents,
      },
      actions: {
        get: vi.fn(),
      },
    },
  },
});

const mountParams = {
  global: {
    plugins: [mockStore],
    mocks: {
      $t: msg => msg,
    },
  },
};

describe('ReportsFiltersAgents.vue', () => {
  it('emits "agentsFilterSelection" event when an agent is added', async () => {
    const wrapper = shallowMount(ReportsFiltersAgents, mountParams);
    const tagInput = wrapper.findComponent(TagInput);

    await tagInput.vm.$emit('add', { value: '1' });
    await tagInput.vm.$emit('add', { value: '2' });

    expect(wrapper.emitted('agentsFilterSelection')).toBeTruthy();
    expect(wrapper.emitted('agentsFilterSelection')[1]).toEqual([agents]);
  });

  it('emits "agentsFilterSelection" without the removed agent', async () => {
    const wrapper = shallowMount(ReportsFiltersAgents, {
      ...mountParams,
      props: { selectedAgents: agents },
    });

    await wrapper.findComponent(TagInput).vm.$emit('remove', 0);

    expect(wrapper.emitted('agentsFilterSelection')[0]).toEqual([[agents[1]]]);
  });

  it('only offers agents that are not selected yet', () => {
    const wrapper = shallowMount(ReportsFiltersAgents, {
      ...mountParams,
      props: { selectedAgents: [agents[0]] },
    });
    const tagInput = wrapper.findComponent(TagInput);

    expect(tagInput.props('modelValue')).toEqual(['Agent 1']);
    expect(tagInput.props('menuItems')).toEqual([
      { action: 'select', value: '2', label: 'Agent 2' },
    ]);
  });

  it('dispatches the "agents/get" action when the component is mounted', () => {
    const dispatchSpy = vi.spyOn(mockStore, 'dispatch');

    shallowMount(ReportsFiltersAgents, mountParams);

    expect(dispatchSpy).toHaveBeenCalledWith('agents/get');
  });
});
