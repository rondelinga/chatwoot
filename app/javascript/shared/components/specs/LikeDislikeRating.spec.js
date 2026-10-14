import { mount } from '@vue/test-utils';
import LikeDislikeRating from '../LikeDislikeRating.vue';

describe('LikeDislikeRating', () => {
  it('emits the like and dislike rating values', async () => {
    const wrapper = mount(LikeDislikeRating);
    const [like, dislike] = wrapper.findAll('button');

    expect(like.text()).toBe('👍');
    expect(dislike.text()).toBe('👎');

    await like.trigger('click');
    await dislike.trigger('click');

    expect(wrapper.emitted('selectRating')).toEqual([[5], [1]]);
  });

  it('highlights the selected rating', () => {
    const wrapper = mount(LikeDislikeRating, { props: { selectedRating: 1 } });
    const [like, dislike] = wrapper.findAll('button');

    expect(dislike.classes()).toContain('!grayscale-0');
    expect(like.classes()).not.toContain('!grayscale-0');
  });

  it('disables the buttons', () => {
    const wrapper = mount(LikeDislikeRating, { props: { isDisabled: true } });

    wrapper.findAll('button').forEach(button => {
      expect(button.attributes('disabled')).toBeDefined();
    });
  });
});
