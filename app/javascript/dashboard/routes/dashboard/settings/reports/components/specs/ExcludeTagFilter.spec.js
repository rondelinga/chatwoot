import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ExcludeTagFilter from '../Csat/ExcludeTagFilter.vue';
import ComboBoxDropdown from 'dashboard/components-next/combobox/ComboBoxDropdown.vue';

const labels = [
  { id: 1, title: 'spam' },
  { id: 2, title: 'vip' },
];

describe('ExcludeTagFilter.vue', () => {
  let getLabels;

  const mountComponent = (selected = []) => {
    getLabels = vi.fn();
    return shallowMount(ExcludeTagFilter, {
      props: { selected },
      global: {
        plugins: [
          createStore({
            getters: { 'labels/getLabels': () => labels },
            actions: { 'labels/get': getLabels },
          }),
        ],
        stubs: { OnClickOutside: { template: '<div><slot /></div>' } },
      },
    });
  };

  it('loads the labels and lists them as options', () => {
    const wrapper = mountComponent(['vip']);

    expect(getLabels).toHaveBeenCalled();
    const dropdown = wrapper.findComponent(ComboBoxDropdown);
    expect(dropdown.props('options')).toEqual([
      { value: 'spam', label: 'spam' },
      { value: 'vip', label: 'vip' },
    ]);
    expect(dropdown.props('selectedValues')).toEqual(['vip']);
  });

  it('toggles a label in the exclusions', () => {
    const wrapper = mountComponent(['vip']);
    const dropdown = wrapper.findComponent(ComboBoxDropdown);

    dropdown.vm.$emit('select', { value: 'spam' });
    dropdown.vm.$emit('select', { value: 'vip' });

    expect(wrapper.emitted('update')).toEqual([[['vip', 'spam']], [[]]]);
  });

  it('removes a label from its chip', async () => {
    const wrapper = mountComponent(['spam', 'vip']);

    const chip = wrapper
      .findAll('button')
      .find(button => button.text() === 'spam');
    await chip.trigger('click');

    expect(wrapper.emitted('update')).toEqual([[['vip']]]);
  });
});
