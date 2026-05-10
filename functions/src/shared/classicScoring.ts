/**
 * Pure helpers for Classic tournament scoring and XP tiers (no Firestore).
 */

/** Number of MCQs in a Classic tournament session. */
export const CLASSIC_TOURNAMENT_QUESTION_COUNT = 20;

/**
 * Counts how many selected indices match the shuffled correct indices (same order).
 *
 * @throws If either array length is not {@link CLASSIC_TOURNAMENT_QUESTION_COUNT}.
 */
export function computeClassicScore(
  answers: number[],
  correctIndices: number[],
): {correctCount: number; totalQuestions: number} {
  if (
    answers.length !== CLASSIC_TOURNAMENT_QUESTION_COUNT ||
    correctIndices.length !== CLASSIC_TOURNAMENT_QUESTION_COUNT
  ) {
    throw new Error("classic_score_requires_length_20");
  }
  let correctCount = 0;
  for (let i = 0; i < CLASSIC_TOURNAMENT_QUESTION_COUNT; i++) {
    if (answers[i] === correctIndices[i]) {
      correctCount++;
    }
  }
  return {correctCount, totalQuestions: CLASSIC_TOURNAMENT_QUESTION_COUNT};
}

/**
 * Rank-based XP grant for Classic tournaments (finalize step only).
 *
 * @throws If rank is less than 1.
 */
export function classicXpForRank(rank: number): number {
  if (rank < 1) {
    throw new Error("classic_xp_invalid_rank");
  }
  if (rank === 1) {
    return 500;
  }
  if (rank === 2 || rank === 3) {
    return 300;
  }
  if (rank >= 4 && rank <= 10) {
    return 200;
  }
  if (rank >= 11 && rank <= 50) {
    return 100;
  }
  return 50;
}
