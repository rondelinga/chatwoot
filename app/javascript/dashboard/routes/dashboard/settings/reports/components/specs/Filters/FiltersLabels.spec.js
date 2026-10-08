import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ReportsFiltersLabels from '../../Filters/Labels.vue';
import TagInput from 'dashboard/components-next/taginput/TagInput.vue';

const labels = [
  { id: 1, title: 'Label 1', color: 'red' },
  { id: 2, title: 'Label 2', color: 'blue' },
];

const mountParams = {
  global: {
    mocks: {
      $t: msg => msg,
    },
  },
};

describe('ReportsFiltersLabels.vue', () => {
  let store;
  let labelsModule;

  const mountComponent = (props = {}) =>
    shallowMount(ReportsFiltersLabels, {
      props,
      global: {
        plugins: [store],
        ...mountParams.global,
      },
    });

  beforeEach(() => {
    labelsModule = {
      namespaced: true,
      getters: {
        getLabels: () => labels,
      },
      actions: {
        get: vi.fn(),
      },
    };

    store = createStore({
      modules: {
        labels: labelsModule,
      },
    });
  });

  it('dispatches "labels/get" action when component is mounted', () => {
    mountComponent();
    expect(labelsModule.actions.get).toHaveBeenCalled();
  });

  it('emits "labelsFilterSelection" event when an option is added', async () => {
    const wrapper = mountComponent();

    await wrapper.findComponent(TagInput).vm.$emit('add', { value: '1' });

    expect(wrapper.emitted('labelsFilterSelection')).toBeTruthy();
    expect(wrapper.emitted('labelsFilterSelection')[0]).toEqual([[labels[0]]]);
  });

  it('emits "labelsFilterSelection" event without the removed option', async () => {
    const wrapper = mountComponent({ selectedLabel: labels });

    await wrapper.findComponent(TagInput).vm.$emit('remove', 0);

    expect(wrapper.emitted('labelsFilterSelection')[0]).toEqual([[labels[1]]]);
  });

  it('only offers options that are not selected yet', () => {
    const wrapper = mountComponent({ selectedLabel: [labels[0]] });
    const tagInput = wrapper.findComponent(TagInput);

    expect(tagInput.props('modelValue')).toEqual([labels[0].title]);
    expect(tagInput.props('menuItems')).toEqual([
      { action: 'select', value: '2', label: labels[1].title },
    ]);
  });
});
