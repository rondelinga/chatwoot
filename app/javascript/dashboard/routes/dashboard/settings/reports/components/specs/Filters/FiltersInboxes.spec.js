import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ReportsFiltersInboxes from '../../Filters/Inboxes.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';

const inboxes = [
  { id: 1, name: 'Inbox 1' },
  { id: 2, name: 'Inbox 2' },
];

const mountParams = {
  global: {
    mocks: {
      $t: msg => msg,
    },
  },
};

describe('ReportsFiltersInboxes.vue', () => {
  let store;
  let inboxesModule;

  const mountComponent = (props = {}) =>
    shallowMount(ReportsFiltersInboxes, {
      props,
      global: {
        plugins: [store],
        ...mountParams.global,
      },
    });

  beforeEach(() => {
    inboxesModule = {
      namespaced: true,
      getters: {
        getInboxes: () => inboxes,
      },
      actions: {
        get: vi.fn(),
      },
    };

    store = createStore({
      modules: {
        inboxes: inboxesModule,
      },
    });
  });

  it('dispatches "inboxes/get" action when component is mounted', () => {
    mountComponent();
    expect(inboxesModule.actions.get).toHaveBeenCalled();
  });

  it('emits "inboxFilterSelection" event when an option is added', async () => {
    const wrapper = mountComponent();

    await wrapper.findComponent(TagInput).vm.$emit('add', { value: '1' });

    expect(wrapper.emitted('inboxFilterSelection')).toBeTruthy();
    expect(wrapper.emitted('inboxFilterSelection')[0]).toEqual([[inboxes[0]]]);
  });

  it('emits "inboxFilterSelection" event without the removed option', async () => {
    const wrapper = mountComponent({ selectedInbox: inboxes });

    await wrapper.findComponent(TagInput).vm.$emit('remove', 0);

    expect(wrapper.emitted('inboxFilterSelection')[0]).toEqual([[inboxes[1]]]);
  });

  it('only offers options that are not selected yet', () => {
    const wrapper = mountComponent({ selectedInbox: [inboxes[0]] });
    const tagInput = wrapper.findComponent(TagInput);

    expect(tagInput.props('modelValue')).toEqual([inboxes[0].name]);
    expect(tagInput.props('menuItems')).toEqual([
      { action: 'select', value: '2', label: inboxes[1].name },
    ]);
  });
});
