/**
 * Accepts either a raw SeaTalk profile ID or a SeaTalk profile link
 * (e.g. `https://link.seatalk.io/profile/open?seatalk_id=12345`,
 * `https://app.seatalk.io/profile?id=12345`, or `seatalk://user?id=12345`)
 * and returns the bare ID string. Empty / whitespace input → null.
 */
export const parseSeatalkProfileId = input => {
  if (input === null || input === undefined) return null;
  const trimmed = String(input).trim();
  if (!trimmed) return null;
  const seatalkIdMatch = trimmed.match(/[?&]seatalk_id=([^&\s#]+)/);
  if (seatalkIdMatch) return seatalkIdMatch[1];
  const idMatch = trimmed.match(/[?&]id=([^&\s#]+)/);
  if (idMatch) return idMatch[1];
  return trimmed;
};
