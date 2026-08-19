import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';

import CannedResponse from '../CannedResponse.vue';

const mountWithMessages = (
  cannedMessages,
  { getCannedResponse, advanceCannedResponseVariant, channelType = '' } = {}
) => {
  const store = createStore({
    getters: {
      getCannedResponses: () => cannedMessages,
    },
    actions: {
      getCannedResponse: getCannedResponse || (() => {}),
      advanceCannedResponseVariant: advanceCannedResponseVariant || (() => {}),
    },
  });

  return shallowMount(CannedResponse, {
    props: { channelType },
    global: {
      plugins: [store],
    },
  });
};

describe('CannedResponse', () => {
  it('groups responses with headers sorted alphabetically by category name', () => {
    const support = { id: 1, name: 'Support' };
    const billing = { id: 2, name: 'Billing' };

    const wrapper = mountWithMessages([
      {
        id: 10,
        short_code: 'ticket',
        content: 'Ticket created',
        files: [],
        category: support,
      },
      {
        id: 20,
        short_code: 'refund',
        content: 'Refund initiated',
        files: [],
        category: billing,
      },
      {
        id: 30,
        short_code: 'close',
        content: 'Closing ticket',
        files: [],
        category: support,
      },
    ]);

    expect(wrapper.vm.items).toEqual([
      { type: 'header', label: 'Billing' },
      {
        label: 'refund',
        key: 20,
        description: 'Refund initiated',
        rotates: false,
        files: [],
        category: billing,
      },
      { type: 'header', label: 'Support' },
      {
        label: 'ticket',
        key: 10,
        description: 'Ticket created',
        rotates: false,
        files: [],
        category: support,
      },
      {
        label: 'close',
        key: 30,
        description: 'Closing ticket',
        rotates: false,
        files: [],
        category: support,
      },
    ]);
  });

  it('keeps keys unique when the same short_code exists in multiple categories', () => {
    const a = { id: 1, name: 'A' };
    const b = { id: 2, name: 'B' };
    const wrapper = mountWithMessages([
      {
        id: 100,
        short_code: 'dup',
        content: 'A version',
        files: [],
        category: a,
      },
      {
        id: 200,
        short_code: 'dup',
        content: 'B version',
        files: [],
        category: b,
      },
    ]);

    const keys = wrapper.vm.items
      .filter(i => i.type !== 'header')
      .map(i => i.key);
    expect(new Set(keys).size).toBe(keys.length);
    expect(keys).toEqual([100, 200]);
  });

  it('defaults files to an empty array when not provided', () => {
    const wrapper = mountWithMessages([
      {
        id: 1,
        short_code: 'hi',
        content: 'Hello',
        category: { id: 1, name: 'X' },
      },
    ]);

    const itemRow = wrapper.vm.items.find(i => i.type !== 'header');
    expect(itemRow.files).toEqual([]);
  });

  it('returns an empty array when there are no canned responses', () => {
    const wrapper = mountWithMessages([]);
    expect(wrapper.vm.items).toEqual([]);
  });

  describe('search fetching', () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it('fetches immediately on mount so the picker is never empty', () => {
      const getCannedResponse = vi.fn();
      mountWithMessages([], { getCannedResponse });

      expect(getCannedResponse).toHaveBeenCalledTimes(1);
    });

    it('collapses a burst of keystrokes into a single request', async () => {
      const getCannedResponse = vi.fn();
      const wrapper = mountWithMessages([], { getCannedResponse });
      getCannedResponse.mockClear();

      await wrapper.setProps({ searchKey: 'i' });
      await wrapper.setProps({ searchKey: 'im' });
      await wrapper.setProps({ searchKey: 'img' });

      expect(getCannedResponse).not.toHaveBeenCalled();

      vi.advanceTimersByTime(300);

      expect(getCannedResponse).toHaveBeenCalledTimes(1);
      expect(getCannedResponse.mock.calls[0][1]).toEqual({
        searchKey: 'img',
        filterByVisibility: true,
      });
    });
  });

  describe('image rendering', () => {
    const withImage = () => [
      {
        id: 1,
        short_code: 'img',
        content: '',
        category: { id: 1, name: 'X' },
        files: [
          {
            blob_id: 7,
            filename: 'card.png',
            file_url: 'https://example.test/blobs/redirect/card.png',
            thumb_url: 'https://example.test/representations/redirect/card.png',
          },
        ],
      },
    ];

    it('renders the thumbnail variant, never the full-size original', () => {
      const wrapper = mountWithMessages(withImage());
      const html = wrapper.html();

      expect(html).not.toContain('/blobs/redirect/');
    });

    it('exposes the untouched file entry so the send path keeps the original', () => {
      const wrapper = mountWithMessages(withImage());
      const itemRow = wrapper.vm.items.find(i => i.type !== 'header');

      expect(itemRow.files[0].file_url).toBe(
        'https://example.test/blobs/redirect/card.png'
      );
    });
  });
});

describe('CannedResponse content variants', () => {
  const category = { id: 1, name: 'General' };
  const withVariants = {
    id: 10,
    short_code: 'hi',
    content: 'hello one',
    content_variants: ['hello two', 'hello three'],
    content_variant_cursor: 1,
    files: [],
    category,
  };

  it('inserts the wording at the cursor on an Instagram conversation', () => {
    const wrapper = mountWithMessages([withVariants], {
      channelType: 'Channel::Instagram',
    });
    const item = wrapper.vm.items.find(i => i.key === 10);

    expect(item.description).toBe('hello two');
    expect(item.rotates).toBe(true);
  });

  it('wraps the cursor around the end of the list', () => {
    const wrapper = mountWithMessages(
      [{ ...withVariants, content_variant_cursor: 3 }],
      { channelType: 'Channel::Instagram' }
    );

    expect(wrapper.vm.items.find(i => i.key === 10).description).toBe(
      'hello one'
    );
  });

  it('ignores blank wordings', () => {
    const wrapper = mountWithMessages(
      [
        {
          ...withVariants,
          content_variants: ['   ', 'hello three'],
          content_variant_cursor: 1,
        },
      ],
      { channelType: 'Channel::Instagram' }
    );

    expect(wrapper.vm.items.find(i => i.key === 10).description).toBe(
      'hello three'
    );
  });

  it('does not rotate on a non-Instagram conversation', () => {
    const wrapper = mountWithMessages([withVariants], {
      channelType: 'Channel::Line',
    });
    const item = wrapper.vm.items.find(i => i.key === 10);

    expect(item.description).toBe('hello one');
    expect(item.rotates).toBe(false);
  });

  it('advances the cursor after inserting a rotating response', () => {
    const advance = vi.fn();
    const wrapper = mountWithMessages([withVariants], {
      channelType: 'Channel::Instagram',
      advanceCannedResponseVariant: advance,
    });

    wrapper.vm.handleMentionClick(wrapper.vm.items.find(i => i.key === 10));

    expect(advance).toHaveBeenCalledTimes(1);
    expect(advance.mock.calls[0][1]).toBe(10);
  });

  it('does not advance the cursor for a response with a single wording', () => {
    const advance = vi.fn();
    const wrapper = mountWithMessages(
      [{ ...withVariants, content_variants: [] }],
      {
        channelType: 'Channel::Instagram',
        advanceCannedResponseVariant: advance,
      }
    );

    wrapper.vm.handleMentionClick(wrapper.vm.items.find(i => i.key === 10));

    expect(advance).not.toHaveBeenCalled();
  });
});
