import { flushPromises, mount } from '@vue/test-utils';
import Response from '../Response.vue';
import LikeDislikeRating from 'shared/components/LikeDislikeRating.vue';
import { getSurveyDetails, updateSurvey } from 'survey/api/survey';

vi.mock('survey/api/survey');
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const surveyResponse = (displayType, csatSurveyResponse = null) => ({
  data: {
    display_type: displayType,
    content: 'Rate us',
    csat_survey_response: csatSurveyResponse,
  },
});

const mountResponse = async () => {
  const wrapper = mount(Response, {
    global: {
      stubs: { Branding: true, Feedback: true, Banner: true },
      directives: { dompurifyHtml: {} },
    },
  });
  await flushPromises();
  return wrapper;
};

describe('Survey Response', () => {
  it('keeps the like/dislike input visible after a rating was submitted', async () => {
    getSurveyDetails.mockResolvedValue(
      surveyResponse('like_dislike', { rating: 5, feedback_message: '' })
    );
    updateSurvey.mockResolvedValue({});
    const wrapper = await mountResponse();

    const rating = wrapper.findComponent(LikeDislikeRating);
    expect(rating.exists()).toBe(true);
    expect(rating.props('selectedRating')).toBe(5);

    await rating.vm.$emit('selectRating', 1);
    await flushPromises();

    expect(updateSurvey).toHaveBeenCalledWith(
      expect.objectContaining({
        data: {
          message: {
            submitted_values: {
              csat_survey_response: { rating: 1, feedback_message: '' },
            },
          },
        },
      })
    );
  });

  it('does not render the like/dislike input for emoji surveys', async () => {
    getSurveyDetails.mockResolvedValue(surveyResponse('emoji'));
    const wrapper = await mountResponse();

    expect(wrapper.findComponent(LikeDislikeRating).exists()).toBe(false);
  });
});
