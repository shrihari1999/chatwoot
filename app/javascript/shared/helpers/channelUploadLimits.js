import { getMaxUploadSizeByChannel } from '@chatwoot/utils';
import { INBOX_TYPES } from 'dashboard/helper/inbox';

/**
 * Fork-only channels are absent from `@chatwoot/utils`' upload rules table, so the
 * package returns its generic default for them. Callers then treat that as "no
 * channel rule" and fall back to the installation limit (MAXIMUM_FILE_UPLOAD_SIZE,
 * 40 MB here) — far above what these platforms actually accept, so the upload is
 * only rejected later by the platform API, after the agent has already sent it.
 *
 * Keyed by channel type, then by MIME category (the part before the `/`).
 *
 * TikTok Shop — `POST /customer_service/202309/images/upload`, the endpoint
 * `Tiktok::Shop::Client#upload_image` calls: "The format of the image must be jpg,
 * gif, webp, or png. The size of the image must not exceed 10MB."
 */
const FORK_CHANNEL_UPLOAD_LIMITS = {
  [INBOX_TYPES.TIKTOK_SHOP]: { image: 10 },
};

/**
 * Maximum upload size in MB for a channel, applying this fork's overrides before
 * delegating to `@chatwoot/utils`. Drop-in replacement for
 * `getMaxUploadSizeByChannel` — same arguments, same return contract.
 *
 * @param {Object} params
 * @param {string} [params.channelType] - Channel type (from INBOX_TYPES).
 * @param {string} [params.medium] - Medium under the channel.
 * @param {string} [params.mime] - MIME type string, e.g. 'image/png'.
 * @returns {number} Maximum file size in MB.
 */
export const getMaxUploadSizeForChannel = ({
  channelType,
  medium,
  mime,
} = {}) => {
  const category = String(mime || '').split('/')[0];
  const override = FORK_CHANNEL_UPLOAD_LIMITS[channelType]?.[category];

  if (override) return override;

  return getMaxUploadSizeByChannel({ channelType, medium, mime });
};
