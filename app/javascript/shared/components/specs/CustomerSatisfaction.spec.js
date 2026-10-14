import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import CustomerSatisfaction from '../CustomerSatisfaction.vue';
import LikeDislikeRating from '../LikeDislikeRating.vue';
import StarRating from '../StarRating.vue';

const submittedValues = (rating, feedbackMessage = '') => ({
  csat_survey_response: { rating, feedback_message: feedbackMessage },
});

describe('CustomerSatisfaction', () => {
  let dispatch;

  const mountComponent = props => {
    const store = createStore({
      modules: {
        appConfig: {
          namespaced: true,
          getters: { getWidgetColor: () => '#1f93ff' },
        },
      },
    });
    dispatch = vi.spyOn(store, 'dispatch').mockResolvedValue();
    return mount(CustomerSatisfaction, {
      props: { messageId: 10, ...props },
      global: {
        plugins: [store],
        stubs: { FluentIcon: true },
        directives: { dompurifyHtml: {} },
      },
    });
  };

  it('renders the star input for the star display type', () => {
    const wrapper = mountComponent({ displayType: 'star' });

    expect(wrapper.findComponent(StarRating).exists()).toBe(true);
    expect(wrapper.findComponent(LikeDislikeRating).exists()).toBe(false);
  });

  describe('like/dislike display type', () => {
    it('submits the rating when the contact clicks dislike', async () => {
      const wrapper = mountComponent({ displayType: 'like_dislike' });

      expect(wrapper.find('form').exists()).toBe(false);

      await wrapper
        .findComponent(LikeDislikeRating)
        .vm.$emit('selectRating', 1);

      expect(dispatch).toHaveBeenCalledWith('message/update', {
        submittedValues: submittedValues(1),
        messageId: 10,
      });
      expect(wrapper.find('input').attributes('placeholder')).toBe(
        'CSAT.DISLIKE_PLACEHOLDER'
      );
    });

    it('keeps the rating editable after feedback was submitted', async () => {
      const wrapper = mountComponent({
        displayType: 'like_dislike',
        message: 'Rate us',
        messageContentAttributes: submittedValues(1, 'too slow'),
      });

      await wrapper.vm.$nextTick();

      expect(wrapper.vm.title).toBe('Rate us');
      expect(wrapper.find('form').exists()).toBe(true);

      await wrapper
        .findComponent(LikeDislikeRating)
        .vm.$emit('selectRating', 5);

      expect(dispatch).toHaveBeenCalledWith('message/update', {
        submittedValues: submittedValues(5),
        messageId: 10,
      });
    });

    it('shows the change rating hint when the survey allows updates', () => {
      const wrapper = mountComponent({
        displayType: 'like_dislike',
        allowUpdate: true,
      });

      expect(wrapper.text()).toContain('CSAT.CHANGE_RATING_HINT');
    });
  });
});
