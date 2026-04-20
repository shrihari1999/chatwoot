import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';

import CannedResponse from '../CannedResponse.vue';

const mountWithMessages = cannedMessages => {
  const store = createStore({
    getters: {
      getCannedResponses: () => cannedMessages,
    },
    actions: {
      getCannedResponse: () => {},
    },
  });

  return shallowMount(CannedResponse, {
    global: {
      plugins: [store],
    },
  });
};

describe('CannedResponse', () => {
  it('returns flat items with no headers when all responses are uncategorised', () => {
    const wrapper = mountWithMessages([
      { short_code: 'hi', content: 'Hello', files: [], category: null },
      { short_code: 'bye', content: 'Goodbye', files: [] },
    ]);

    expect(wrapper.vm.items).toEqual([
      {
        label: 'hi',
        key: 'hi',
        description: 'Hello',
        files: [],
        category: null,
      },
      {
        label: 'bye',
        key: 'bye',
        description: 'Goodbye',
        files: [],
        category: null,
      },
    ]);
  });

  it('groups categorised responses with headers sorted alphabetically by category name', () => {
    const support = { id: 1, name: 'Support' };
    const billing = { id: 2, name: 'Billing' };

    const wrapper = mountWithMessages([
      {
        short_code: 'ticket',
        content: 'Ticket created',
        files: [],
        category: support,
      },
      {
        short_code: 'refund',
        content: 'Refund initiated',
        files: [],
        category: billing,
      },
      {
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
        key: 'refund',
        description: 'Refund initiated',
        files: [],
        category: billing,
      },
      { type: 'header', label: 'Support' },
      {
        label: 'ticket',
        key: 'ticket',
        description: 'Ticket created',
        files: [],
        category: support,
      },
      {
        label: 'close',
        key: 'close',
        description: 'Closing ticket',
        files: [],
        category: support,
      },
    ]);
  });

  it('appends an "Other" header with uncategorised responses when mixed with categorised ones', () => {
    const support = { id: 1, name: 'Support' };

    const wrapper = mountWithMessages([
      {
        short_code: 'hi',
        content: 'Hello',
        files: [],
        category: null,
      },
      {
        short_code: 'ticket',
        content: 'Ticket created',
        files: [],
        category: support,
      },
    ]);

    expect(wrapper.vm.items).toEqual([
      { type: 'header', label: 'Support' },
      {
        label: 'ticket',
        key: 'ticket',
        description: 'Ticket created',
        files: [],
        category: support,
      },
      { type: 'header', label: 'Other' },
      {
        label: 'hi',
        key: 'hi',
        description: 'Hello',
        files: [],
        category: null,
      },
    ]);
  });

  it('defaults files to an empty array when not provided', () => {
    const wrapper = mountWithMessages([{ short_code: 'hi', content: 'Hello' }]);

    expect(wrapper.vm.items[0].files).toEqual([]);
  });

  it('returns an empty array when there are no canned responses', () => {
    const wrapper = mountWithMessages([]);
    expect(wrapper.vm.items).toEqual([]);
  });
});
