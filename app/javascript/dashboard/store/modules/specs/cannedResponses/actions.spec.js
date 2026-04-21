import axios from 'axios';
import CannedResponses from '../../cannedResponse';
import * as types from '../../../mutation-types';

const { actions } = CannedResponses;

const commit = vi.fn();
global.axios = axios;
vi.mock('axios');

describe('#actions', () => {
  describe('#deleteCannedResponse', () => {
    beforeEach(() => {
      commit.mockClear();
    });

    it('commits deletingItem: false after successful delete', async () => {
      axios.delete.mockResolvedValue({ data: {} });
      await actions.deleteCannedResponse({ commit }, 1);
      expect(commit.mock.calls).toEqual([
        [types.default.SET_CANNED_UI_FLAG, { deletingItem: true }],
        [types.default.DELETE_CANNED, 1],
        [types.default.SET_CANNED_UI_FLAG, { deletingItem: false }],
      ]);
    });

    it('commits deletingItem: false after failed delete', async () => {
      axios.delete.mockRejectedValue({ message: 'Network Error' });
      await expect(actions.deleteCannedResponse({ commit }, 1)).rejects.toThrow(
        Error
      );
      expect(commit.mock.calls).toEqual([
        [types.default.SET_CANNED_UI_FLAG, { deletingItem: true }],
        [types.default.SET_CANNED_UI_FLAG, { deletingItem: false }],
      ]);
    });

    it('does NOT leave deletingItem: true stuck after success', async () => {
      axios.delete.mockResolvedValue({ data: {} });
      await actions.deleteCannedResponse({ commit }, 42);
      const lastCall = commit.mock.calls[commit.mock.calls.length - 1];
      expect(lastCall).toEqual([
        types.default.SET_CANNED_UI_FLAG,
        { deletingItem: false },
      ]);
    });

    it('does NOT leave deletingItem: true stuck after error', async () => {
      axios.delete.mockRejectedValue({ message: 'Server Error' });
      await expect(
        actions.deleteCannedResponse({ commit }, 42)
      ).rejects.toThrow(Error);
      const lastCall = commit.mock.calls[commit.mock.calls.length - 1];
      expect(lastCall).toEqual([
        types.default.SET_CANNED_UI_FLAG,
        { deletingItem: false },
      ]);
    });
  });
});
