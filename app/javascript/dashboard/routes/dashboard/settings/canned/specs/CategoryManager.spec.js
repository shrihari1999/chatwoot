import { shallowMount } from '@vue/test-utils';
import { createStore } from 'vuex';
import CategoryManager from '../CategoryManager.vue';

const createMockStore = ({ categories = [], dispatch = vi.fn() } = {}) => {
  const store = createStore({
    modules: {
      cannedResponseCategory: {
        namespaced: true,
        getters: {
          getCannedResponseCategories: () => categories,
        },
      },
    },
  });
  store.dispatch = dispatch;
  return store;
};

const mountComponent = ({ categories = [], dispatch = vi.fn() } = {}) => {
  const store = createMockStore({ categories, dispatch });
  return shallowMount(CategoryManager, {
    global: {
      plugins: [store],
      mocks: {
        $t: key => key,
      },
      stubs: {
        NextButton: {
          template:
            '<button :disabled="disabled" @click="$emit(\'click\')"><slot /></button>',
          props: ['label', 'disabled', 'isLoading', 'size', 'type', 'icon'],
        },
        Icon: true,
        CategoryDialog: true,
      },
    },
  });
};

describe('CategoryManager.vue', () => {
  it('renders existing categories', () => {
    const categories = [
      { id: 1, name: 'Greetings', visibility: 'everyone' },
      { id: 2, name: 'Billing', visibility: 'everyone' },
    ];
    const wrapper = mountComponent({ categories });
    expect(wrapper.text()).toContain('Greetings');
    expect(wrapper.text()).toContain('Billing');
  });

  it('renders no chip when there are no categories', () => {
    const wrapper = mountComponent({ categories: [] });
    expect(wrapper.findAll('span.inline-flex').length).toBe(0);
  });

  it('opens the dialog in add mode when Add Category is clicked', async () => {
    const wrapper = mountComponent();
    expect(wrapper.vm.showDialog).toBe(false);

    await wrapper.find('button').trigger('click');

    expect(wrapper.vm.showDialog).toBe(true);
    expect(wrapper.vm.editingCategory).toBeNull();
  });

  it('opens the dialog in edit mode when a category name is clicked', async () => {
    const categories = [{ id: 1, name: 'Greetings', visibility: 'everyone' }];
    const wrapper = mountComponent({ categories });

    const nameBtn = wrapper
      .find('span.inline-flex')
      .find('button[type="button"]');
    await nameBtn.trigger('click');

    expect(wrapper.vm.showDialog).toBe(true);
    expect(wrapper.vm.editingCategory).toEqual(categories[0]);
  });

  it('closes the dialog and clears editing state', () => {
    const wrapper = mountComponent();
    wrapper.vm.openEditDialog({ id: 9, name: 'X' });
    wrapper.vm.closeDialog();
    expect(wrapper.vm.showDialog).toBe(false);
    expect(wrapper.vm.editingCategory).toBeNull();
  });

  it('shows a visibility icon for non-everyone categories', () => {
    const wrapper = mountComponent();
    expect(wrapper.vm.visibilityIcon({ visibility: 'only_me' })).toBe(
      'i-lucide-lock'
    );
    expect(wrapper.vm.visibilityIcon({ visibility: 'specific_team' })).toBe(
      'i-lucide-users'
    );
    expect(wrapper.vm.visibilityIcon({ visibility: 'everyone' })).toBeNull();
  });

  // Delete: the delete button is the second button inside each chip (index 1)
  it('dispatches deleteCannedResponseCategory when confirm returns true', async () => {
    const dispatch = vi.fn().mockResolvedValue({});
    const categories = [{ id: 42, name: 'Greetings', visibility: 'everyone' }];
    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);
    const wrapper = mountComponent({ categories, dispatch });

    const buttons = wrapper
      .find('span.inline-flex')
      .findAll('button[type="button"]');
    await buttons[1].trigger('click'); // delete button
    await wrapper.vm.$nextTick();

    expect(dispatch).toHaveBeenCalledWith(
      'cannedResponseCategory/deleteCannedResponseCategory',
      42
    );
    confirmSpy.mockRestore();
  });

  it('refreshes canned responses after a successful category delete', async () => {
    const dispatch = vi.fn().mockResolvedValue({});
    const categories = [{ id: 42, name: 'Greetings', visibility: 'everyone' }];
    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);
    const wrapper = mountComponent({ categories, dispatch });

    const buttons = wrapper
      .find('span.inline-flex')
      .findAll('button[type="button"]');
    await buttons[1].trigger('click');
    await wrapper.vm.$nextTick();
    await wrapper.vm.$nextTick();

    expect(dispatch).toHaveBeenCalledWith(
      'cannedResponseCategory/deleteCannedResponseCategory',
      42
    );
    expect(dispatch).toHaveBeenCalledWith('getCannedResponse');
    confirmSpy.mockRestore();
  });

  it('does not dispatch delete when confirm returns false', async () => {
    const dispatch = vi.fn().mockResolvedValue({});
    const categories = [{ id: 42, name: 'Greetings', visibility: 'everyone' }];
    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(false);
    const wrapper = mountComponent({ categories, dispatch });

    const buttons = wrapper
      .find('span.inline-flex')
      .findAll('button[type="button"]');
    await buttons[1].trigger('click');

    expect(dispatch).not.toHaveBeenCalled();
    confirmSpy.mockRestore();
  });
});
