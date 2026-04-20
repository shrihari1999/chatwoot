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
          props: ['label', 'disabled', 'isLoading', 'size', 'type'],
        },
        Icon: true,
      },
    },
  });
};

describe('CategoryManager.vue', () => {
  it('renders existing categories', () => {
    const categories = [
      { id: 1, name: 'Greetings' },
      { id: 2, name: 'Billing' },
    ];
    const wrapper = mountComponent({ categories });
    expect(wrapper.text()).toContain('Greetings');
    expect(wrapper.text()).toContain('Billing');
  });

  it('renders no chip when there are no categories', () => {
    const wrapper = mountComponent({ categories: [] });
    expect(wrapper.findAll('span.inline-flex').length).toBe(0);
  });

  it('disables Add button when input is empty', () => {
    const wrapper = mountComponent();
    // canAdd computed reflects the disabled state
    expect(wrapper.vm.canAdd).toBe(false);
  });

  it('enables Add button when input has a value', async () => {
    const wrapper = mountComponent();
    await wrapper.find('input[type="text"]').setValue('My Category');
    expect(wrapper.vm.canAdd).toBe(true);
  });

  it('treats whitespace-only input as empty', async () => {
    const wrapper = mountComponent();
    await wrapper.find('input[type="text"]').setValue('   ');
    expect(wrapper.vm.canAdd).toBe(false);
  });

  it('dispatches createCannedResponseCategory on submit', async () => {
    const dispatch = vi.fn().mockResolvedValue({});
    const wrapper = mountComponent({ dispatch });

    await wrapper.find('input[type="text"]').setValue('New Cat');
    await wrapper.find('form').trigger('submit.prevent');

    expect(dispatch).toHaveBeenCalledWith(
      'cannedResponseCategory/createCannedResponseCategory',
      { name: 'New Cat' }
    );
  });

  it('does not dispatch on submit when input is blank', async () => {
    const dispatch = vi.fn().mockResolvedValue({});
    const wrapper = mountComponent({ dispatch });

    await wrapper.find('input[type="text"]').setValue('   ');
    await wrapper.find('form').trigger('submit.prevent');

    expect(dispatch).not.toHaveBeenCalled();
  });

  it('dispatches deleteCannedResponseCategory when confirm returns true', async () => {
    const dispatch = vi.fn().mockResolvedValue({});
    const categories = [{ id: 42, name: 'Greetings' }];
    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);
    const wrapper = mountComponent({ categories, dispatch });

    const deleteBtn = wrapper.find('span.inline-flex button[type="button"]');
    await deleteBtn.trigger('click');
    await wrapper.vm.$nextTick();

    expect(dispatch).toHaveBeenCalledWith(
      'cannedResponseCategory/deleteCannedResponseCategory',
      42
    );
    confirmSpy.mockRestore();
  });

  it('refreshes canned responses after a successful category delete', async () => {
    const dispatch = vi.fn().mockResolvedValue({});
    const categories = [{ id: 42, name: 'Greetings' }];
    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);
    const wrapper = mountComponent({ categories, dispatch });

    const deleteBtn = wrapper.find('span.inline-flex button[type="button"]');
    await deleteBtn.trigger('click');
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
    const categories = [{ id: 42, name: 'Greetings' }];
    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(false);
    const wrapper = mountComponent({ categories, dispatch });

    const deleteBtn = wrapper.find('span.inline-flex button[type="button"]');
    await deleteBtn.trigger('click');

    expect(dispatch).not.toHaveBeenCalled();
    confirmSpy.mockRestore();
  });
});
