import { getMaxUploadSizeForChannel } from '../channelUploadLimits';
import { getMaxUploadSizeByChannel } from '@chatwoot/utils';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

vi.mock('@chatwoot/utils', () => ({
  getMaxUploadSizeByChannel: vi.fn(),
}));

describe('getMaxUploadSizeForChannel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    getMaxUploadSizeByChannel.mockReturnValue(40);
  });

  describe('TikTok Shop override', () => {
    it('caps images at 10 MB per the /customer_service/202309/images/upload limit', () => {
      expect(
        getMaxUploadSizeForChannel({
          channelType: INBOX_TYPES.TIKTOK_SHOP,
          mime: 'image/png',
        })
      ).toBe(10);
      expect(getMaxUploadSizeByChannel).not.toHaveBeenCalled();
    });

    it('applies to every image MIME, not just png', () => {
      ['image/jpeg', 'image/gif', 'image/webp'].forEach(mime => {
        expect(
          getMaxUploadSizeForChannel({
            channelType: INBOX_TYPES.TIKTOK_SHOP,
            mime,
          })
        ).toBe(10);
      });
    });

    it('delegates non-image MIMEs on the same channel to the package', () => {
      getMaxUploadSizeByChannel.mockReturnValue(40);

      expect(
        getMaxUploadSizeForChannel({
          channelType: INBOX_TYPES.TIKTOK_SHOP,
          mime: 'video/mp4',
        })
      ).toBe(40);
      expect(getMaxUploadSizeByChannel).toHaveBeenCalledWith({
        channelType: INBOX_TYPES.TIKTOK_SHOP,
        medium: undefined,
        mime: 'video/mp4',
      });
    });
  });

  describe('delegation', () => {
    it('passes channelType, medium and mime through untouched', () => {
      getMaxUploadSizeByChannel.mockReturnValue(5);

      expect(
        getMaxUploadSizeForChannel({
          channelType: INBOX_TYPES.WHATSAPP,
          medium: 'whatsapp',
          mime: 'image/png',
        })
      ).toBe(5);
      expect(getMaxUploadSizeByChannel).toHaveBeenCalledWith({
        channelType: INBOX_TYPES.WHATSAPP,
        medium: 'whatsapp',
        mime: 'image/png',
      });
    });

    it('does not override channels the package already knows about', () => {
      getMaxUploadSizeByChannel.mockReturnValue(3);

      expect(
        getMaxUploadSizeForChannel({
          channelType: INBOX_TYPES.TIKTOK,
          mime: 'image/png',
        })
      ).toBe(3);
    });
  });

  describe('edge cases', () => {
    it('delegates when mime is missing on an overridden channel', () => {
      getMaxUploadSizeByChannel.mockReturnValue(40);

      expect(
        getMaxUploadSizeForChannel({ channelType: INBOX_TYPES.TIKTOK_SHOP })
      ).toBe(40);
      expect(getMaxUploadSizeByChannel).toHaveBeenCalled();
    });

    it('delegates when called with no arguments', () => {
      getMaxUploadSizeByChannel.mockReturnValue(40);

      expect(getMaxUploadSizeForChannel()).toBe(40);
      expect(getMaxUploadSizeByChannel).toHaveBeenCalledWith({
        channelType: undefined,
        medium: undefined,
        mime: undefined,
      });
    });
  });
});
