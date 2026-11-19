import { nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import AgentTable from '../overview/AgentTable.vue';

vi.mock('shared/components/Spinner.vue', () => ({
  default: { name: 'Spinner', template: '<div />' },
}));

const buildAgents = (count, status = 'offline') =>
  Array.from({ length: count }, (_, index) => {
    const number = String(index + 1).padStart(2, '0');
    return {
      id: index + 1,
      name: `Agent ${number}`,
      email: `agent${number}@example.com`,
      availability_status: status,
    };
  });

const store = createStore({
  getters: {
    getUISettings: () => ({}),
    'accounts/isRTL': () => false,
  },
  actions: {
    updateUISettings: () => {},
  },
});

const mountTable = (agents = buildAgents(12)) =>
  mount(AgentTable, {
    props: { agents, agentMetrics: [], isLoading: false },
    global: {
      plugins: [store],
      stubs: {
        FilterSelect: true,
        Avatar: true,
        Icon: true,
      },
    },
  });

const clickPage = async (wrapper, page) => {
  const button = wrapper
    .findAll('button')
    .find(item => item.text().trim() === String(page));
  await button.trigger('click');
  await nextTick();
};

describe('AgentTable', () => {
  it('keeps the current page when the agent list is replaced', async () => {
    const wrapper = mountTable();

    await clickPage(wrapper, 2);
    expect(wrapper.text()).toContain('Agent 11');
    expect(wrapper.text()).not.toContain('Agent 01');

    await wrapper.setProps({
      agents: buildAgents(12).map(agent => ({
        ...agent,
        availability_status: 'online',
      })),
    });
    await nextTick();

    expect(wrapper.text()).toContain('Agent 11');
    expect(wrapper.text()).not.toContain('Agent 01');
    wrapper.unmount();
  });

  it('moves back when the current page no longer exists', async () => {
    const wrapper = mountTable();

    await clickPage(wrapper, 2);
    await wrapper.setProps({ agents: buildAgents(3) });
    await nextTick();

    expect(wrapper.text()).toContain('Agent 01');
    expect(wrapper.text()).not.toContain('Agent 11');
    wrapper.unmount();
  });
});
