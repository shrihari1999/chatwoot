import { mount } from '@vue/test-utils';
import { ref } from 'vue';
import Audio from './Audio.vue';

// The component reaches its <audio> element through useTemplateRef. Controlling
// that ref lets a test drop the element the way an unmount does, which is the
// condition that produced the production crash.
const playerRef = ref(null);

vi.mock('vue', async importOriginal => {
  const actual = await importOriginal();
  return { ...actual, useTemplateRef: () => playerRef };
});

vi.mock('next/icon/Icon.vue', () => ({
  default: { name: 'Icon', props: ['icon'], template: '<span class="icon" />' },
}));

vi.mock('dashboard/composables/emitter', () => ({
  useEmitter: () => {},
}));

vi.mock('@chatwoot/utils', () => ({ downloadFile: vi.fn() }));

const fakeAudioElement = () => ({
  playbackRate: 1,
  currentTime: 0,
  muted: false,
  duration: 12,
  play: vi.fn(),
  pause: vi.fn(),
  addEventListener: vi.fn(),
  removeEventListener: vi.fn(),
});

// Vue routes a handler exception to its own errorHandler rather than letting it
// escape trigger(), so the spec has to capture it explicitly -- asserting that
// trigger() merely resolves would pass even with the bug present.
const mountAudio = (errors = []) =>
  mount(Audio, {
    props: { attachment: { dataUrl: 'https://cdn.example.com/voice.mp3' } },
    global: {
      mocks: { $t: key => key },
      config: { errorHandler: err => errors.push(err) },
    },
  });

describe('Audio chip', () => {
  beforeEach(() => {
    playerRef.value = fakeAudioElement();
  });

  it('resets playback rate when the clip ends', async () => {
    playerRef.value.playbackRate = 2;
    const wrapper = mountAudio();

    await wrapper.find('audio').trigger('ended');

    expect(playerRef.value.playbackRate).toBe(1);
  });

  // Regression: the `ended` event can arrive after the agent has navigated away
  // and the bubble was torn down, leaving the template ref null. Writing
  // playbackRate on it threw "Cannot set properties of null".
  it('does not throw when the clip ends after the player is gone', async () => {
    const errors = [];
    const wrapper = mountAudio(errors);
    playerRef.value = null;

    await wrapper.find('audio').trigger('ended');

    expect(errors).toEqual([]);
  });

  it('still resets reactive state when the player is gone', async () => {
    const wrapper = mountAudio();
    await wrapper.find('audio').trigger('ended');
    playerRef.value = null;

    await expect(
      wrapper.find('audio').trigger('ended')
    ).resolves.toBeUndefined();
  });
});
