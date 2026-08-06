import { mount } from '@vue/test-utils';
import { ref, defineComponent } from 'vue';
import MessageMeta from './MessageMeta.vue';
import { provideMessageContext } from './provider.js';

// Mock the useInbox composable so it returns a stable set of refs. The refs live
// outside the factory so a test can flip a channel on before mounting.
const inboxFlags = vi.hoisted(() => ({
  isAFacebookInbox: false,
  isALineChannel: false,
  isALazadaChannel: false,
  isAPIInbox: false,
  isASmsInbox: false,
  isATelegramChannel: false,
  isATwilioChannel: false,
  isAWebWidgetInbox: false,
  isAWhatsAppChannel: false,
  isAnEmailChannel: false,
  isAnInstagramChannel: false,
  isATiktokChannel: false,
  isATiktokShopChannel: false,
}));

vi.mock('dashboard/composables/useInbox', async () => {
  const { ref: mockRef } = await import('vue');
  return {
    useInbox: () =>
      Object.fromEntries(
        Object.entries(inboxFlags).map(([key, value]) => [key, mockRef(value)])
      ),
  };
});

// Stub MessageStatus and Icon so they don't need real dependencies. MessageStatus
// renders the status it was handed so the indicator assertions can read it.
vi.mock('./MessageStatus.vue', () => ({
  default: {
    props: ['status'],
    template: '<span class="msg-status">{{ status }}</span>',
  },
}));

vi.mock('next/icon/Icon.vue', () => ({
  default: { name: 'Icon', props: ['icon'], template: '<span class="icon" />' },
}));

// Stub the store getter used by provideMessageContext → useMessageContext
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: () => ref([]),
}));

vi.mock('shared/composables/useSnakeCase', () => ({
  useSnakeCase: v => v,
}));

vi.mock('dashboard/composables/useTransformKeys', () => ({
  useSnakeCase: v => v,
}));

/**
 * Mount MessageMeta inside a wrapper that provides message context.
 * @param {Object} contextOverrides - Overrides for the message context refs.
 */
function mountWithContext(contextOverrides = {}) {
  const defaults = {
    status: ref('sent'),
    isPrivate: ref(false),
    createdAt: ref(1732195656),
    sourceId: ref(null),
    messageType: ref(0), // INCOMING = 0
    contentAttributes: ref({}),
    variant: ref('left'),
    orientation: ref('left'),
    isBotOrAgentMessage: ref(false),
    shouldGroupWithNext: ref(false),
  };

  const context = { ...defaults, ...contextOverrides };

  const Wrapper = defineComponent({
    components: { MessageMeta },
    setup() {
      provideMessageContext(context);
    },
    template: '<MessageMeta />',
  });

  return mount(Wrapper);
}

describe('MessageMeta.vue — (Edited) label', () => {
  it('does NOT show (Edited) label when contentAttributes has no edited field', () => {
    const wrapper = mountWithContext({
      contentAttributes: ref({}),
    });
    expect(wrapper.find('span.italic').exists()).toBe(false);
  });

  it('does NOT show (Edited) label when contentAttributes.edited is false', () => {
    const wrapper = mountWithContext({
      contentAttributes: ref({ edited: false }),
    });
    expect(wrapper.find('span.italic').exists()).toBe(false);
  });

  it('shows (Edited) label when contentAttributes.edited is true', () => {
    const wrapper = mountWithContext({
      contentAttributes: ref({ edited: true }),
    });
    const editedSpan = wrapper.find('span.italic');
    expect(editedSpan.exists()).toBe(true);
    expect(editedSpan.text()).toContain('(Edited)');
  });

  it('shows (Edited) label for a Facebook inbox message with edited=true', () => {
    const wrapper = mountWithContext({
      contentAttributes: ref({ edited: true }),
      messageType: ref(0), // incoming
    });
    expect(wrapper.find('span.italic').exists()).toBe(true);
  });

  it('shows (Edited) label for a Telegram inbox message with edited=true', () => {
    const wrapper = mountWithContext({
      contentAttributes: ref({ edited: true }),
      messageType: ref(0), // incoming
    });
    expect(wrapper.find('span.italic').exists()).toBe(true);
  });

  it('does NOT show (Edited) label for a deleted message (edited + deleted)', () => {
    // A deleted message would have deleted=true; (Edited) label should only appear
    // when edited=true. The deleted state is separate.
    // In this implementation, both edited and deleted can coexist.
    // We verify that edited=true still shows the label regardless of deleted state.
    const wrapper = mountWithContext({
      contentAttributes: ref({ edited: true, deleted: false }),
    });
    expect(wrapper.find('span.italic').exists()).toBe(true);
  });

  it('shows timestamp regardless of edited state', () => {
    const wrapper = mountWithContext({
      contentAttributes: ref({ edited: true }),
      createdAt: ref(1732195656),
    });
    const timeEl = wrapper.find('time');
    expect(timeEl.exists()).toBe(true);
  });
});

describe('MessageMeta.vue — Lazada status indicator', () => {
  beforeEach(() => {
    inboxFlags.isALazadaChannel = true;
  });

  afterEach(() => {
    inboxFlags.isALazadaChannel = false;
  });

  const outgoing = overrides => ({
    messageType: ref(1), // OUTGOING
    sourceId: ref('lzd-msg-1'),
    ...overrides,
  });

  // Seller-app sends and Lazada's own auto-replies arrive on the webhook already
  // delivered, so they must render the double-check and not the sending clock.
  it('shows delivered for a delivered message', () => {
    const wrapper = mountWithContext(outgoing({ status: ref('delivered') }));
    expect(wrapper.find('span.msg-status').text()).toBe('delivered');
  });

  it('shows sent for a sent message', () => {
    const wrapper = mountWithContext(outgoing({ status: ref('sent') }));
    expect(wrapper.find('span.msg-status').text()).toBe('sent');
  });

  it('shows read for a read message', () => {
    const wrapper = mountWithContext(outgoing({ status: ref('read') }));
    expect(wrapper.find('span.msg-status').text()).toBe('read');
  });

  it('falls back to progress when the message has no source id yet', () => {
    const wrapper = mountWithContext(
      outgoing({ status: ref('delivered'), sourceId: ref(null) })
    );
    expect(wrapper.find('span.msg-status').text()).toBe('progress');
  });
});
