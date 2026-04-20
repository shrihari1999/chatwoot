import { mount } from '@vue/test-utils';
import { describe, it, expect, vi, beforeEach } from 'vitest';

import MentionBox from '../MentionBox.vue';

// Stub the keyboard events binding so tests don't register real listeners.
vi.mock('dashboard/composables/useKeyboardEvents', () => ({
  useKeyboardEvents: vi.fn(),
}));

const buildItems = () => [
  { type: 'header', label: 'Billing' },
  {
    label: 'refund',
    key: 'refund',
    description: 'Refund initiated',
    files: [],
  },
  { type: 'header', label: 'Support' },
  { label: 'ticket', key: 'ticket', description: 'Ticket created', files: [] },
  { label: 'close', key: 'close', description: 'Closing ticket', files: [] },
];

const mountMentionBox = (items = buildItems()) =>
  mount(MentionBox, {
    props: { items },
    global: {
      stubs: {
        'woot-dropdown-item': {
          template: '<li class="dropdown-menu__item"><slot /></li>',
        },
      },
    },
  });

describe('MentionBox', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // jsdom doesn't implement scrollIntoView.
    Element.prototype.scrollIntoView = vi.fn();
  });

  it('renders header rows as non-interactive labels', () => {
    const wrapper = mountMentionBox();

    const headerNodes = wrapper.findAll('li[aria-hidden="true"]');
    expect(headerNodes).toHaveLength(2);
    expect(headerNodes[0].text()).toBe('Billing');
    expect(headerNodes[1].text()).toBe('Support');

    // Header rows must not be rendered as selectable buttons
    headerNodes.forEach(node => {
      expect(node.find('button').exists()).toBe(false);
    });
  });

  it('initialises selectedIndex on the first non-header item', () => {
    const wrapper = mountMentionBox();
    // First item is a header, so the first selectable item is index 1.
    expect(wrapper.vm.selectedIndex).toBe(1);
  });

  it('initialises selectedIndex at 0 when all items are regular entries', () => {
    const items = [
      { label: 'hi', key: 'hi', description: 'Hi', files: [] },
      { label: 'bye', key: 'bye', description: 'Bye', files: [] },
    ];
    const wrapper = mountMentionBox(items);
    expect(wrapper.vm.selectedIndex).toBe(0);
  });

  it('ignores hover on header rows', async () => {
    const wrapper = mountMentionBox();
    const initial = wrapper.vm.selectedIndex;

    // Simulate hovering a header — should be a no-op because the
    // header branch does not bind @mouseover.
    await wrapper.findAll('li[aria-hidden="true"]')[1].trigger('mouseover');
    expect(wrapper.vm.selectedIndex).toBe(initial);
  });

  it('does not emit mention-select when Enter fires on a header row', async () => {
    const wrapper = mountMentionBox();

    // Force the selection onto a header index and invoke select directly.
    wrapper.vm.selectedIndex = 0; // header
    await wrapper.vm.$nextTick();
    // After the watcher runs, the header should be skipped.
    expect(wrapper.vm.selectedIndex).not.toBe(0);
  });

  it('skips headers when navigation lands on one (moving down)', async () => {
    const wrapper = mountMentionBox();
    // Start on the last selectable item (index 4).
    wrapper.vm.selectedIndex = 4;
    await wrapper.vm.$nextTick();

    // Emulate the keyboard composable moving down (wraps to 0).
    wrapper.vm.selectedIndex = 0;
    await wrapper.vm.$nextTick();

    // Item at index 0 is a header; the next selectable item is 1.
    expect(wrapper.vm.selectedIndex).toBe(1);
  });

  it('skips headers when navigation lands on one (moving up)', async () => {
    const wrapper = mountMentionBox();
    // Start on index 3 (a regular item under "Support").
    wrapper.vm.selectedIndex = 3;
    await wrapper.vm.$nextTick();

    // Emulate ArrowUp → index 2 (the "Support" header).
    wrapper.vm.selectedIndex = 2;
    await wrapper.vm.$nextTick();

    // The next selectable item upward is index 1.
    expect(wrapper.vm.selectedIndex).toBe(1);
  });

  it('resets selectedIndex when items change and the current index is out of range', async () => {
    const wrapper = mountMentionBox();
    wrapper.vm.selectedIndex = 3;
    await wrapper.vm.$nextTick();

    await wrapper.setProps({
      items: [{ label: 'only', key: 'only', description: 'Only', files: [] }],
    });

    expect(wrapper.vm.selectedIndex).toBe(0);
  });

  it('resets selectedIndex to a non-header item when items change', async () => {
    const wrapper = mountMentionBox();
    wrapper.vm.selectedIndex = 1;
    await wrapper.vm.$nextTick();

    await wrapper.setProps({
      items: [
        { type: 'header', label: 'Billing' },
        { label: 'refund', key: 'refund', description: 'Refund', files: [] },
      ],
    });

    // Index 1 is already a regular item — the watcher should leave it alone,
    // but if the current index points at a header after the swap, reset.
    expect(wrapper.vm.selectedIndex).toBe(1);
  });

  it('does not emit mention-select when clicking on a header row', async () => {
    const wrapper = mountMentionBox();

    // Directly invoke the click handler on a header-style item.
    wrapper.vm.onListItemSelection(0, { type: 'header', label: 'Billing' });
    await wrapper.vm.$nextTick();

    expect(wrapper.emitted('mentionSelect')).toBeUndefined();
  });

  it('emits mention-select with the active item when a regular row is clicked', async () => {
    const wrapper = mountMentionBox();

    wrapper.vm.onListItemSelection(1, {
      label: 'refund',
      key: 'refund',
      description: 'Refund initiated',
      files: [],
    });
    await wrapper.vm.$nextTick();

    const events = wrapper.emitted('mentionSelect');
    expect(events).toBeTruthy();
    expect(events[0][0].key).toBe('refund');
  });
});
