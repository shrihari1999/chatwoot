import { mount } from '@vue/test-utils';
import InstagramStory from './InstagramStory.vue';

// The bubble reads everything through useMessageContext; the refs live outside
// the factory so a test can set the attachments before mounting.
const context = vi.hoisted(() => ({
  attachments: [],
  content: '',
  contentAttributes: {},
}));

vi.mock('../provider.js', async () => {
  const { ref: mockRef } = await import('vue');
  return {
    useMessageContext: () => ({
      variant: mockRef('agent'),
      content: mockRef(context.content),
      contentAttributes: mockRef(context.contentAttributes),
      attachments: mockRef(context.attachments),
    }),
  };
});

vi.mock('next/message/bubbles/Base.vue', () => ({
  default: { name: 'BaseBubble', template: '<div><slot /></div>' },
}));

vi.mock('next/icon/Icon.vue', () => ({
  default: { name: 'Icon', props: ['icon'], template: '<span class="icon" />' },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const mountStory = () =>
  mount(InstagramStory, {
    global: {
      directives: { dompurifyHtml: () => {} },
      mocks: { $t: key => key },
    },
  });

describe('InstagramStory', () => {
  beforeEach(() => {
    context.attachments = [];
    context.content = '';
    context.contentAttributes = {};
  });

  it('renders the story image when an attachment is present', () => {
    context.attachments = [{ dataUrl: 'https://cdn.example.com/story.jpg' }];

    const wrapper = mountStory();

    expect(wrapper.find('img').attributes('src')).toBe(
      'https://cdn.example.com/story.jpg'
    );
  });

  // Regression: a load-error handler firing after the agent navigated away left
  // attachments empty, and the img branch still evaluated attachment.dataUrl,
  // throwing "Cannot read properties of undefined (reading 'dataUrl')".
  it('falls back to the unavailable state when there is no attachment', () => {
    context.attachments = [];

    expect(() => mountStory()).not.toThrow();

    const wrapper = mountStory();
    expect(wrapper.find('img').exists()).toBe(false);
    expect(wrapper.find('video').exists()).toBe(false);
    expect(wrapper.text()).toContain(
      'COMPONENTS.FILE_BUBBLE.INSTAGRAM_STORY_UNAVAILABLE'
    );
  });

  it('does not crash when the image errors and the attachment is gone', async () => {
    context.attachments = [{ dataUrl: 'https://cdn.example.com/story.jpg' }];
    const wrapper = mountStory();

    await wrapper.find('img').trigger('error');

    // Image failed, so it retries as a video rather than crashing.
    expect(wrapper.find('video').exists()).toBe(true);
    expect(wrapper.emitted('error')).toBeTruthy();
  });
});
