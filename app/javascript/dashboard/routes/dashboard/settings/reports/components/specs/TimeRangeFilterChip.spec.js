import { mount } from '@vue/test-utils';
import TimeRangeFilterChip from '../Filters/v3/TimeRangeFilterChip.vue';

describe('TimeRangeFilterChip.vue', () => {
  const mountComponent = () =>
    mount(TimeRangeFilterChip, {
      props: { since: '00:00', until: '23:59' },
      global: { directives: { onClickaway: {} } },
    });

  it('shows the selected time range in UTC', () => {
    const wrapper = mountComponent();

    expect(wrapper.text()).toContain('00:00');
    expect(wrapper.text()).toContain('23:59');
    expect(wrapper.text()).toContain(
      'AGENT_ACTIVITY_REPORTS.FILTERS.TIME_ZONE_UTC'
    );
  });

  it('emits the updated range when a time changes', async () => {
    const wrapper = mountComponent();
    expect(wrapper.find('input[type="time"]').exists()).toBe(false);

    await wrapper.find('button').trigger('click');
    const [sinceInput, untilInput] = wrapper.findAll('input[type="time"]');

    await sinceInput.setValue('08:30');
    expect(wrapper.emitted('change').at(-1)).toEqual([
      { since: '08:30', until: '23:59' },
    ]);

    await untilInput.setValue('17:00');
    expect(wrapper.emitted('change').at(-1)).toEqual([
      { since: '00:00', until: '17:00' },
    ]);
  });

  it('ignores cleared time inputs', async () => {
    const wrapper = mountComponent();
    await wrapper.find('button').trigger('click');

    await wrapper.find('input[type="time"]').setValue('');

    expect(wrapper.emitted('change')).toBeUndefined();
  });
});
