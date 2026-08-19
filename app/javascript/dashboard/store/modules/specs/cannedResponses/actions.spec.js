import axios from 'axios';
import CannedResponses from '../../cannedResponse';
import * as types from '../../../mutation-types';
import * as Sentry from '@sentry/vue';

// The Sentry exports are an ESM namespace, so they cannot be spied on in place.
vi.mock('@sentry/vue', () => ({
  captureException: vi.fn(),
  setContext: vi.fn(),
}));

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

  describe('#advanceCannedResponseVariant', () => {
    it('posts to the advance_variant endpoint', async () => {
      axios.post.mockResolvedValue({ data: { content_variant_cursor: 1 } });

      await actions.advanceCannedResponseVariant({ commit }, 7);

      expect(axios.post).toHaveBeenCalledWith(
        expect.stringContaining('/canned_responses/7/advance_variant')
      );
    });

    it('reports a failed bump to Sentry without surfacing it to the agent', async () => {
      const error = new Error('boom');
      axios.post.mockRejectedValue(error);
      Sentry.captureException.mockClear();
      Sentry.setContext.mockClear();

      // Resolves rather than rejects: the agent must never see this fail.
      await expect(
        actions.advanceCannedResponseVariant({ commit }, 7)
      ).resolves.toBeUndefined();

      expect(Sentry.setContext).toHaveBeenCalledWith(
        'canned response variant',
        {
          cannedResponseId: 7,
        }
      );
      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });
  });
});
