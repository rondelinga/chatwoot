import { flushPromises, mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import AddAgents from '../AddAgents.vue';
import InboxTeamsAPI from 'dashboard/api/inboxTeams';

const routerReplace = vi.fn();

vi.mock('../../../../index', () => ({
  default: { replace: (...args) => routerReplace(...args) },
}));

vi.mock('dashboard/api/inboxTeams', () => ({
  default: { update: vi.fn().mockResolvedValue({}) },
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

const teams = [
  { id: 1, name: 'Support' },
  { id: 2, name: 'Sales' },
];

const store = createStore({
  modules: {
    teams: {
      namespaced: true,
      getters: { getTeams: () => teams },
      actions: { get: () => {} },
    },
    routingTypes: {
      namespaced: true,
      getters: {
        getRoutingTypes: () => [{ id: 10, name: 'VIP' }],
      },
      actions: { get: () => {} },
    },
    agentBots: {
      namespaced: true,
      getters: {
        getBots: () => [{ id: 7, name: 'Helper' }],
      },
      actions: { get: () => {} },
    },
  },
});

const mountForm = () =>
  mount(AddAgents, {
    global: {
      plugins: [store],
      mocks: {
        $t: key => key,
        $route: { params: { inbox_id: 42 } },
      },
      stubs: {
        PageHeader: true,
        NextButton: {
          template: '<button type="submit"><slot /></button>',
        },
        TagInput: {
          props: ['modelValue'],
          template: `
            <div>
              <button type="button" data-testid="add-team-1" @click="$emit('add', { value: 1 })" />
              <button type="button" data-testid="add-team-2" @click="$emit('add', { value: 2 })" />
            </div>
          `,
        },
      },
    },
  });

describe('AddAgents', () => {
  beforeEach(() => {
    routerReplace.mockClear();
    InboxTeamsAPI.update.mockClear();
  });

  it('keeps routing settings when another team is added and sends them on submit', async () => {
    const wrapper = mountForm();
    await flushPromises();

    await wrapper.get('[data-testid="add-team-1"]').trigger('click');
    const [routingSelect, botSelect] = wrapper.findAll('select');
    await routingSelect.setValue(10);
    await botSelect.setValue(7);

    await wrapper.get('[data-testid="add-team-2"]').trigger('click');

    const selects = wrapper.findAll('select');
    expect(selects[0].element.value).toBe('10');
    expect(selects[1].element.value).toBe('7');
    expect(wrapper.get('input[type="radio"]').element.checked).toBe(true);

    await wrapper.find('form').trigger('submit');
    await flushPromises();

    expect(InboxTeamsAPI.update).toHaveBeenCalledWith({
      inboxId: 42,
      teamConfigs: [
        {
          team_id: 1,
          is_default: true,
          routing_type_id: 10,
          agent_bot_id: 7,
        },
        {
          team_id: 2,
          is_default: false,
          routing_type_id: null,
          agent_bot_id: null,
        },
      ],
    });
  });
});
