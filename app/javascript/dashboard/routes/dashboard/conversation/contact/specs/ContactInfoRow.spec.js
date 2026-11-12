import { shallowMount } from '@vue/test-utils';
import ContactInfoRow from '../ContactInfoRow.vue';

const mountComponent = (props, slots = {}) =>
  shallowMount(ContactInfoRow, {
    props: { icon: 'map', emoji: '🌍', ...props },
    slots,
    global: { mocks: { $t: key => key } },
  });

describe('ContactInfoRow', () => {
  const markup = '<form><input name="field"></form><img src="x">Acme';

  it('renders values without a link as plain text', () => {
    const wrapper = mountComponent({ value: markup });

    expect(wrapper.find('form').exists()).toBe(false);
    expect(wrapper.find('input').exists()).toBe(false);
    expect(wrapper.find('img').exists()).toBe(false);
    expect(wrapper.text()).toContain(markup);
  });

  it('applies a value class without treating the value as markup', () => {
    const wrapper = mountComponent({
      value: 'Не авторизован',
      valueClass: 'text-n-ruby-11',
    });

    const value = wrapper.find('span[title="Не авторизован"]');
    expect(value.classes()).toContain('text-n-ruby-11');
    expect(value.text()).toBe('Не авторизован');
  });

  it('renders slot content next to the value', () => {
    const wrapper = mountComponent(
      { value: 'Northtown, Northland' },
      { default: '<span class="flag" />' }
    );

    expect(wrapper.find('.flag').exists()).toBe(true);
  });
});
