/**
 * Live tournament finalize: rank-based XP (distinct from Classic tiers).
 */

/**
 * XP by competition rank for Live tournaments (BRAINJAMIN Live scale).
 *
 * @throws If rank is less than 1.
 */
export function liveXpForRank(rank: number): number {
  if (rank < 1) {
    throw new Error("live_xp_invalid_rank");
  }
  if (rank === 1) {
    return 1000;
  }
  if (rank === 2 || rank === 3) {
    return 600;
  }
  if (rank >= 4 && rank <= 10) {
    return 400;
  }
  if (rank >= 11 && rank <= 50) {
    return 200;
  }
  return 100;
}
