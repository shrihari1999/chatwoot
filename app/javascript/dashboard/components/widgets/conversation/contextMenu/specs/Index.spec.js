import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { describe, expect, it, beforeEach, vi } from 'vitest';
import ContextMenu from '../Index.vue';

describe('ContextMenu (Index.vue)', () => {
  let store;
  let wrapper;

  const defaultProps = {
    chatId: 1,
    status: 'open',
    hasUnreadMessages: false,
    inboxId: 1,
    priority: null,
    conversationLabels: [],
    conversationUrl: '/app/accounts/1/conversations/1',
    allowedOptions: [],
  };

  beforeEach(() => {
    store = createStore({
      getters: {
        getCurrentUser: () => ({ id: 1, account_id: 1 }),
        getCurrentAccountId: () => 1,
      },
      modules: {
        labels: {
          namespaced: true,
          getters: { getLabels: () => [] },
        },
        teams: {
          namespaced: true,
          getters: { getTeams: () => [] },
        },
        inboxAssignableAgents: {
          namespaced: true,
          getters: {
            getUIFlags: () => ({ isFetching: false }),
            getAssignableAgents: () => () => [],
          },
          actions: {
            fetch: vi.fn(),
          },
        },
      },
    });

    wrapper = shallowMount(ContextMenu, {
      global: {
        plugins: [store],
        mocks: {
          $t: msg => msg,
        },
      },
      props: defaultProps,
    });
  });

  it('does not contain a delete menu option in the rendered output', () => {
    const html = wrapper.html();
    expect(html).not.toContain('CONVERSATION.CARD_CONTEXT_MENU.DELETE');
  });

  it('does not have deleteConversation in the emits definition', () => {
    const emitsOption = wrapper.vm.$options.emits;
    expect(emitsOption).not.toContain('deleteConversation');
  });

  it('does not expose a deleteConversation method', () => {
    expect(wrapper.vm.deleteConversation).toBeUndefined();
  });

  it('does not have a delete key in the MENU constant', () => {
    const menuData = wrapper.vm.MENU;
    const menuKeys = Object.keys(menuData).map(k => k.toLowerCase());
    expect(menuKeys).not.toContain('delete');
  });

  it('does not include a deleteOption in the data properties', () => {
    expect(wrapper.vm.deleteOption).toBeUndefined();
  });

  it('does not expose isAdmin from setup', () => {
    expect(wrapper.vm.isAdmin).toBeUndefined();
  });

  it('still renders existing menu items (no accidental over-removal)', () => {
    // With shallowMount, child components are stubbed, so verify via
    // the component's own data that the expected options remain defined.
    expect(wrapper.vm.unreadOption).toBeDefined();
    expect(wrapper.vm.readOption).toBeDefined();
    expect(wrapper.vm.statusMenuConfig).toBeDefined();
    expect(wrapper.vm.snoozeOption).toBeDefined();
    expect(wrapper.vm.priorityConfig).toBeDefined();
    expect(wrapper.vm.labelMenuConfig).toBeDefined();
    expect(wrapper.vm.agentMenuConfig).toBeDefined();
    expect(wrapper.vm.teamMenuConfig).toBeDefined();
    expect(wrapper.vm.openInNewTabOption).toBeDefined();
    expect(wrapper.vm.copyLinkOption).toBeDefined();
  });
});
