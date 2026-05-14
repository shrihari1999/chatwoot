/**
 * Accepts either a raw SeaTalk profile ID or a SeaTalk profile link
 * (e.g. `https://app.seatalk.io/profile?id=12345` or `seatalk://user?id=12345`)
 * and returns the bare ID string. Empty / whitespace input → null.
 */
export const parseSeatalkProfileId = input => {
  if (input === null || input === undefined) return null;
  const trimmed = String(input).trim();
  if (!trimmed) return null;
  const match = trimmed.match(/[?&]id=([^&\s#]+)/);
  return match ? match[1] : trimmed;
};
