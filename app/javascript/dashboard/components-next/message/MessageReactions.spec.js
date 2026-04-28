import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import MessageReactions from './MessageReactions.vue';

describe('MessageReactions', () => {
  it('renders nothing when reactions is empty', () => {
    const wrapper = mount(MessageReactions, {
      props: { reactions: {} },
    });
    expect(wrapper.find('[data-testid="reaction-pill"]').exists()).toBe(false);
  });

  it('renders one pill for one emoji with one sender', () => {
    const wrapper = mount(MessageReactions, {
      props: { reactions: { '❤️': ['psid1'] } },
    });
    const pills = wrapper.findAll('[data-testid="reaction-pill"]');
    expect(pills).toHaveLength(1);
    expect(pills[0].text()).toContain('❤️');
    expect(pills[0].text()).toContain('1');
  });

  it('shows count 2 for one emoji with two senders', () => {
    const wrapper = mount(MessageReactions, {
      props: { reactions: { '❤️': ['psid1', 'psid2'] } },
    });
    const pills = wrapper.findAll('[data-testid="reaction-pill"]');
    expect(pills[0].text()).toContain('2');
  });

  it('renders multiple pills for multiple emojis', () => {
    const wrapper = mount(MessageReactions, {
      props: { reactions: { '❤️': ['psid1'], '😂': ['psid2', 'psid3'] } },
    });
    expect(wrapper.findAll('[data-testid="reaction-pill"]')).toHaveLength(2);
  });

  it('filters out emojis with empty sender arrays', () => {
    const wrapper = mount(MessageReactions, {
      props: { reactions: { '❤️': [], '😂': ['psid1'] } },
    });
    const pills = wrapper.findAll('[data-testid="reaction-pill"]');
    expect(pills).toHaveLength(1);
    expect(pills[0].text()).toContain('😂');
  });
});
