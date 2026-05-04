export const DIFFICULTIES = [1, 2, 3, 4, 5] as const;
export type Difficulty = typeof DIFFICULTIES[number];

export const DIFFICULTY_LABELS: Record<Difficulty, string> = {
  1: "very_easy",
  2: "easy",
  3: "medium",
  4: "hard",
  5: "very_hard",
};

export function isDifficulty(x: unknown): x is Difficulty {
  return typeof x === "number" && DIFFICULTIES.includes(x as Difficulty);
}
