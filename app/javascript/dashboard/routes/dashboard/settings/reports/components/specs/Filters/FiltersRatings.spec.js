import { shallowMount } from '@vue/test-utils';
import ReportFiltersRatings from '../../Filters/Ratings.vue';
import { CSAT_RATINGS } from 'shared/constants/messages';

const mountParams = {
  global: {
    mocks: {
      $t: msg => msg,
    },
  },
};

describe('ReportFiltersRatings.vue', () => {
  it('emits "ratingFilterSelection" event when a rating is selected', async () => {
    const wrapper = shallowMount(ReportFiltersRatings, mountParams);

    const selectedRating = CSAT_RATINGS[0];
    await wrapper.find('select').setValue(String(selectedRating.value));

    expect(wrapper.emitted('ratingFilterSelection')).toBeTruthy();
    expect(wrapper.emitted('ratingFilterSelection')[0]).toEqual([
      { ...selectedRating, label: selectedRating.translationKey },
    ]);
  });

  it('renders options from the highest to the lowest rating', () => {
    const wrapper = shallowMount(ReportFiltersRatings, mountParams);

    const ratingOptions = wrapper.findAll('option:not([disabled])');
    const expectedOptions = [...CSAT_RATINGS].reverse();

    expect(ratingOptions.map(option => option.element.value)).toEqual(
      expectedOptions.map(option => String(option.value))
    );
    expect(ratingOptions.map(option => option.text())).toEqual(
      expectedOptions.map(option => option.translationKey)
    );
  });
});
