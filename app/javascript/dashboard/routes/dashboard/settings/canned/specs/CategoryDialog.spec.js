import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import CategoryDialog from '../CategoryDialog.vue';

const teams = [
  { id: 1, name: 'Sales' },
  { id: 2, name: 'Support' },
];

const createMockStore = (dispatch = vi.fn()) => {
  const store = createStore({
    modules: {
      teams: {
        namespaced: true,
        getters: { getTeams: () => teams },
      },
    },
  });
  store.dispatch = dispatch;
  return store;
};

const mountComponent = ({ category = null, dispatch = vi.fn() } = {}) => {
  const store = createMockStore(dispatch);
  return mount(CategoryDialog, {
    props: { category, onClose: vi.fn() },
    global: {
      plugins: [store],
      mocks: { $t: key => key },
      stubs: {
        Modal: { template: '<div><slot /></div>' },
        'woot-modal-header': { template: '<div><slot /></div>' },
        NextButton: {
          template:
            '<button :disabled="disabled" :type="type" @click="$emit(\'click\', $event)"><slot /></button>',
          props: ['label', 'disabled', 'isLoading', 'type'],
        },
      },
    },
  });
};

describe('CategoryDialog.vue', () => {
  it('renders the add title when no category is passed', () => {
    const wrapper = mountComponent();
    expect(wrapper.vm.isEditing).toBe(false);
    expect(wrapper.vm.title).toBe('CANNED_MGMT.CATEGORY.DIALOG.ADD_TITLE');
  });

  it('pre-fills fields and uses the edit title when a category is passed', () => {
    const category = {
      id: 7,
      name: 'Billing',
      visibility: 'specific_team',
      team_id: 2,
    };
    const wrapper = mountComponent({ category });
    expect(wrapper.vm.isEditing).toBe(true);
    expect(wrapper.vm.title).toBe('CANNED_MGMT.CATEGORY.DIALOG.EDIT_TITLE');
    expect(wrapper.vm.name).toBe('Billing');
    expect(wrapper.vm.visibility).toBe('specific_team');
    expect(wrapper.vm.teamId).toBe(2);
  });

  it('defaults a new category to everyone visibility', () => {
    const wrapper = mountComponent();
    expect(wrapper.vm.visibility).toBe('everyone');
  });

  it('shows the team selector only for specific_team visibility', async () => {
    const wrapper = mountComponent();
    expect(wrapper.find('select').exists()).toBe(false);

    wrapper.vm.visibility = 'specific_team';
    await wrapper.vm.$nextTick();
    expect(wrapper.find('select').exists()).toBe(true);
  });

  it('dispatches create with the visibility payload on submit', async () => {
    const dispatch = vi.fn().mockResolvedValue({});
    const wrapper = mountComponent({ dispatch });

    wrapper.vm.name = 'Greetings';
    await wrapper.find('form').trigger('submit');

    expect(dispatch).toHaveBeenCalledWith(
      'cannedResponseCategory/createCannedResponseCategory',
      { name: 'Greetings', visibility: 'everyone', team_id: null }
    );
  });

  it('dispatches update in edit mode', async () => {
    const dispatch = vi.fn().mockResolvedValue({});
    const category = { id: 7, name: 'Billing', visibility: 'everyone' };
    const wrapper = mountComponent({ category, dispatch });

    wrapper.vm.name = 'Billing Renamed';
    await wrapper.find('form').trigger('submit');

    expect(dispatch).toHaveBeenCalledWith(
      'cannedResponseCategory/updateCannedResponseCategory',
      { id: 7, name: 'Billing Renamed', visibility: 'everyone', team_id: null }
    );
  });

  it('does not submit a specific_team category without a team', async () => {
    const dispatch = vi.fn().mockResolvedValue({});
    const wrapper = mountComponent({ dispatch });

    wrapper.vm.name = 'Team Cat';
    wrapper.vm.visibility = 'specific_team';
    await wrapper.vm.$nextTick();
    await wrapper.find('form').trigger('submit');

    expect(dispatch).not.toHaveBeenCalled();
  });

  it('sends the selected team id for a specific_team category', async () => {
    const dispatch = vi.fn().mockResolvedValue({});
    const wrapper = mountComponent({ dispatch });

    wrapper.vm.name = 'Team Cat';
    wrapper.vm.visibility = 'specific_team';
    wrapper.vm.teamId = 1;
    await wrapper.vm.$nextTick();
    await wrapper.find('form').trigger('submit');

    expect(dispatch).toHaveBeenCalledWith(
      'cannedResponseCategory/createCannedResponseCategory',
      { name: 'Team Cat', visibility: 'specific_team', team_id: 1 }
    );
  });
});
