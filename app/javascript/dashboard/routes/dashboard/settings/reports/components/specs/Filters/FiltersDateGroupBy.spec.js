import { shallowMount } from '@vue/test-utils';
import ReportsFiltersDateGroupBy from '../../Filters/DateGroupBy.vue';
import { GROUP_BY_OPTIONS } from '../../../constants';

const mountParams = {
  global: {
    mocks: {
      $t: msg => msg,
    },
  },
};

const validGroupOptions = [
  GROUP_BY_OPTIONS.DAY,
  GROUP_BY_OPTIONS.WEEK,
  GROUP_BY_OPTIONS.MONTH,
];

describe('ReportsFiltersDateGroupBy.vue', () => {
  it('emits "onGroupingChange" event when a grouping option is selected', async () => {
    const wrapper = shallowMount(ReportsFiltersDateGroupBy, {
      ...mountParams,
      props: { validGroupOptions },
    });

    await wrapper.find('select').setValue(GROUP_BY_OPTIONS.WEEK.id);

    expect(wrapper.emitted('onGroupingChange')).toBeTruthy();
    expect(wrapper.emitted('onGroupingChange')[0]).toEqual([
      {
        ...GROUP_BY_OPTIONS.WEEK,
        groupBy: GROUP_BY_OPTIONS.WEEK.translationKey,
      },
    ]);
  });

  it('updates the selected value when selectedOption is changed', async () => {
    const wrapper = shallowMount(ReportsFiltersDateGroupBy, {
      ...mountParams,
      props: { validGroupOptions },
    });

    await wrapper.setProps({ selectedOption: GROUP_BY_OPTIONS.MONTH });

    expect(wrapper.find('select').element.value).toBe(
      GROUP_BY_OPTIONS.MONTH.id
    );
  });

  it('renders translated options correctly', () => {
    const wrapper = shallowMount(ReportsFiltersDateGroupBy, {
      ...mountParams,
      props: { validGroupOptions },
    });

    const options = wrapper.findAll('option');

    expect(options.map(option => option.element.value)).toEqual(
      validGroupOptions.map(option => option.id)
    );
    expect(options.map(option => option.text())).toEqual(
      validGroupOptions.map(option => option.translationKey)
    );
  });
});
