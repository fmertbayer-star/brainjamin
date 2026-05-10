/**
 * Fixed equal difficulty mix for Classic tournaments: 4 questions per level 1–5.
 */

import type {Difficulty} from "./difficulty";

/** Twenty difficulties in slot order: four × each level 1–5. */
export const TOURNAMENT_DIFFICULTY_PLAN: readonly Difficulty[] = [
  1, 1, 1, 1,
  2, 2, 2, 2,
  3, 3, 3, 3,
  4, 4, 4, 4,
  5, 5, 5, 5,
];

/**
 * Maps linear slot index 0–19 to difficulty using {@link TOURNAMENT_DIFFICULTY_PLAN}.
 */
export function difficultyForSlotIndex(slotIndex: number): Difficulty {
  if (!Number.isInteger(slotIndex) || slotIndex < 0 || slotIndex >= 20) {
    throw new Error(`difficultyForSlotIndex: slotIndex must be 0–19, got ${slotIndex}`);
  }
  return TOURNAMENT_DIFFICULTY_PLAN[slotIndex];
}
