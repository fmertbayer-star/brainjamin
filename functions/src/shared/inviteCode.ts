/**
 * Shared invite code generation for features that distribute joinable
 * codes (Arena, future Duel refactor).
 *
 * Format: bare 6-character string drawn from a 32-character alphabet
 * that excludes ambiguous glyphs (0, 1, I, L, O). Per BRAINJAMIN.md
 * § PRODUCT § Duel — invite code, this format is shared across
 * features for visual consistency.
 *
 * Collision handling is the caller's responsibility (regenerate on
 * Firestore uniqueness conflict).
 */

import {randomBytes} from "crypto";

export const INVITE_CODE_ALPHABET =
  "23456789ABCDEFGHJKMNPQRSTUVWXYZ";

export const INVITE_CODE_LENGTH = 6;

export function generateInviteCode(): string {
  const bytes = randomBytes(INVITE_CODE_LENGTH);
  let out = "";
  for (let i = 0; i < INVITE_CODE_LENGTH; i++) {
    out += INVITE_CODE_ALPHABET[bytes[i] % INVITE_CODE_ALPHABET.length];
  }
  return out;
}
