import { throwErrorMessage } from 'dashboard/store/utils/api';
import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import * as types from '../mutation-types';
import CannedResponseCategoryAPI from '../../api/cannedResponseCategory';

const state = {
  records: [],
  uiFlags: {
    fetchingList: false,
    creatingItem: false,
    updatingItem: false,
    deletingItem: false,
  },
};

const getters = {
  getCannedResponseCategories(_state) {
    return _state.records;
  },
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

const actions = {
  getCannedResponseCategories: async function getCannedResponseCategories({
    commit,
  }) {
    commit(types.default.SET_CANNED_CATEGORY_UI_FLAG, { fetchingList: true });
    try {
      const response = await CannedResponseCategoryAPI.get();
      commit(types.default.SET_CANNED_CATEGORIES, response.data);
      commit(types.default.SET_CANNED_CATEGORY_UI_FLAG, {
        fetchingList: false,
      });
    } catch (error) {
      commit(types.default.SET_CANNED_CATEGORY_UI_FLAG, {
        fetchingList: false,
      });
    }
  },

  createCannedResponseCategory: async function createCannedResponseCategory(
    { commit },
    name
  ) {
    commit(types.default.SET_CANNED_CATEGORY_UI_FLAG, { creatingItem: true });
    try {
      const response = await CannedResponseCategoryAPI.create(name);
      commit(types.default.ADD_CANNED_CATEGORY, response.data);
      commit(types.default.SET_CANNED_CATEGORY_UI_FLAG, {
        creatingItem: false,
      });
      return response.data;
    } catch (error) {
      commit(types.default.SET_CANNED_CATEGORY_UI_FLAG, {
        creatingItem: false,
      });
      return throwErrorMessage(error);
    }
  },

  updateCannedResponseCategory: async function updateCannedResponseCategory(
    { commit },
    { id, name }
  ) {
    commit(types.default.SET_CANNED_CATEGORY_UI_FLAG, { updatingItem: true });
    try {
      const response = await CannedResponseCategoryAPI.update(id, name);
      commit(types.default.EDIT_CANNED_CATEGORY, response.data);
      commit(types.default.SET_CANNED_CATEGORY_UI_FLAG, {
        updatingItem: false,
      });
      return response.data;
    } catch (error) {
      commit(types.default.SET_CANNED_CATEGORY_UI_FLAG, {
        updatingItem: false,
      });
      return throwErrorMessage(error);
    }
  },

  deleteCannedResponseCategory: async function deleteCannedResponseCategory(
    { commit },
    id
  ) {
    commit(types.default.SET_CANNED_CATEGORY_UI_FLAG, { deletingItem: true });
    try {
      await CannedResponseCategoryAPI.delete(id);
      commit(types.default.DELETE_CANNED_CATEGORY, id);
      commit(types.default.SET_CANNED_CATEGORY_UI_FLAG, {
        deletingItem: false,
      });
      return id;
    } catch (error) {
      commit(types.default.SET_CANNED_CATEGORY_UI_FLAG, {
        deletingItem: false,
      });
      return throwErrorMessage(error);
    }
  },
};

const mutations = {
  [types.default.SET_CANNED_CATEGORY_UI_FLAG](_state, data) {
    _state.uiFlags = {
      ..._state.uiFlags,
      ...data,
    };
  },

  [types.default.SET_CANNED_CATEGORIES]: MutationHelpers.set,
  [types.default.ADD_CANNED_CATEGORY]: MutationHelpers.create,
  [types.default.EDIT_CANNED_CATEGORY]: MutationHelpers.update,
  [types.default.DELETE_CANNED_CATEGORY]: MutationHelpers.destroy,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
