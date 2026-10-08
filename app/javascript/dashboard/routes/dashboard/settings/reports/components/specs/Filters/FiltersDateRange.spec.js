import { shallowMount } from '@vue/test-utils';
import ReportFiltersDateRange from '../../Filters/DateRange.vue';
import { DATE_RANGE_OPTIONS } from '../../../constants';

describe('ReportFiltersDateRange.vue', () => {
  it('emits "onRangeChange" event when a range is selected', async () => {
    const wrapper = shallowMount(ReportFiltersDateRange);

    const selectedRange = DATE_RANGE_OPTIONS.LAST_7_DAYS;
    await wrapper.find('select').setValue(selectedRange.id);

    expect(wrapper.emitted('onRangeChange')).toBeTruthy();
    expect(wrapper.emitted('onRangeChange')[0]).toEqual([
      { ...selectedRange, name: selectedRange.translationKey },
    ]);
  });

  it('renders options correctly', () => {
    const wrapper = shallowMount(ReportFiltersDateRange);

    const expectedIds = Object.values(DATE_RANGE_OPTIONS).map(
      option => option.id
    );
    const receivedIds = wrapper
      .findAll('option')
      .map(option => option.element.value);

    expect(receivedIds).toEqual(expectedIds);
  });

  it('selects the first range by default', () => {
    const wrapper = shallowMount(ReportFiltersDateRange);
    const expectedId = Object.values(DATE_RANGE_OPTIONS)[0].id;
    expect(wrapper.find('select').element.value).toBe(expectedId);
  });
});
